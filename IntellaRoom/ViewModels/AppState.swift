import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

final class AppState: ObservableObject {
    let db = Firestore.firestore()
    let storage = Storage.storage().reference()

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil

    // Data Collections
    @Published var projects: [Project] = []
    @Published var drawings: [Drawing] = []
    @Published var rooms: [Room] = []
    @Published var savedScans: [Scan] = []
    
    @Published var activeDrawingId: UUID?

    // MARK: - Initializers & Auth Helpers
    // (You can add your init or auth state listeners here later)
}

// MARK: - Projects
extension AppState {
    func loadProjectsForCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).collection("projects")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let loaded = documents.compactMap { doc -> Project? in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let foreman = data["foreman"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                    return Project(id: UUID(uuidString: doc.documentID) ?? UUID(), name: name, foreman: foreman, createdAt: createdAt)
                }
                DispatchQueue.main.async { self.projects = loaded }
            }
    }

    @discardableResult
    func createProject(name: String, foreman: String) -> Project {
        guard let uid = Auth.auth().currentUser?.uid else { fatalError("No User") }
        let projectId = UUID()
        let project = Project(id: projectId, name: name, foreman: foreman, createdAt: Date())
        let data: [String: Any] = ["name": name, "foreman": foreman, "createdAt": FieldValue.serverTimestamp()]

        db.collection("users").document(uid).collection("projects").document(projectId.uuidString).setData(data)
        projects.insert(project, at: 0)
        return project
    }

    func deleteProject(_ project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let projectIdString = project.id.uuidString

        // 1. Delete the Project Document from Firestore
        db.collection("users").document(uid)
            .collection("projects").document(projectIdString)
            .delete { error in
                if let error = error {
                    print("❌ Firestore Delete Error: \(error.localizedDescription)")
                } else {
                    print("💾 Firestore Project Document deleted")
                }
            }

        // 2. Cloud Storage Cleanup (Recursive Delete)
        let projectStorageRef = storage.child("projects/\(projectIdString)")
        
        projectStorageRef.listAll { (result, error) in
            if let error = error {
                print("⚠️ Storage List Error: \(error.localizedDescription)")
                return
            }

            // Delete any files in the root project folder
            result?.items.forEach { file in
                file.delete { _ in print("🗑️ Deleted root file: \(file.name)") }
            }

            // Dig into sub-folders (like 'drawings') and delete those files too
            result?.prefixes.forEach { folder in
                folder.listAll { (subResult, _) in
                    subResult?.items.forEach { file in
                        file.delete { _ in print("🗑️ Deleted sub-folder file: \(file.name)") }
                    }
                }
            }
        }

        // 3. Local Folder Cleanup
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectFolder = documents.appendingPathComponent("Projects").appendingPathComponent(projectIdString)
        
        try? FileManager.default.removeItem(at: projectFolder)
        print("📂 Local files removed")

        // 4. Update UI State
        DispatchQueue.main.async {
            self.projects.removeAll { $0.id == project.id }
            self.drawings.removeAll { $0.projectId == project.id }
            self.rooms.removeAll { $0.projectId == projectIdString }
            
            if let activeId = self.activeDrawingId,
               self.drawings.first(where: { $0.id == activeId }) == nil {
                self.activeDrawingId = nil
            }
            print("✅ UI State cleaned for project: \(project.name)")
        }
    }
}

// MARK: - Drawings
extension AppState {
    func drawings(for project: Project) -> [Drawing] {
        drawings.filter { $0.projectId == project.id }
    }

    @MainActor
    func ensureDrawingPDFExists(_ drawing: Drawing) async {
        // 1. Check local file system first
        if FileManager.default.fileExists(atPath: drawing.localURL.path) {
            return
        }

        // 2. Prepare the reference
        // IMPORTANT: We use drawing.storagePath directly from the database record
        let ref = storage.child(drawing.storagePath)

        print("⬇️ iPad attempting download from: \(drawing.storagePath)")

        do {
            // 3. Create the local directory if it somehow got deleted
            let folderURL = drawing.localURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // 4. Download
            try await ref.writeAsync(toFile: drawing.localURL)
            print("✅ iPad successfully synced PDF: \(drawing.name)")
        } catch {
            let nsError = error as NSError
            // If it's a 404, the path in the database doesn't match the path in Storage
            if nsError.code == StorageErrorCode.objectNotFound.rawValue {
                print("❌ 404 Error: The iPad is looking for a file that doesn't exist at this path in Storage.")
                print("🔗 Check Firebase Console Storage tab for: \(drawing.storagePath)")
            } else {
                print("❌ Download failed: \(error.localizedDescription)")
            }
        }
    }

    func loadDrawings(for project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("projects").document(project.id.uuidString).collection("drawings")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let loaded = documents.compactMap { doc -> Drawing? in
                    let data = doc.data()
                    guard let name = data["name"] as? String, let storagePath = data["storagePath"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                    let drawingId = UUID(uuidString: doc.documentID) ?? UUID()
                    let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Projects/\(project.id.uuidString)/Drawings/\(drawingId.uuidString).pdf")
                    return Drawing(id: drawingId, projectId: project.id, name: name, storagePath: storagePath, localURL: localURL, createdAt: createdAt)
                }
                DispatchQueue.main.async {
                    self.drawings = loaded
                    Task { for d in loaded { await self.ensureDrawingPDFExists(d) } }
                }
            }
    }

    func addDrawing(from pickedURL: URL, to project: Project) async throws -> Drawing {
        guard pickedURL.startAccessingSecurityScopedResource() else { throw NSError(domain: "Auth", code: 1) }
        defer { pickedURL.stopAccessingSecurityScopedResource() }

        let drawingId = UUID()
        let fileName = pickedURL.deletingPathExtension().lastPathComponent
        let localDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Projects/\(project.id.uuidString)/Drawings", isDirectory: true)
        try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        let destinationURL = localDir.appendingPathComponent("\(drawingId.uuidString).pdf")

        try Data(contentsOf: pickedURL).write(to: destinationURL, options: .atomic)

        let storagePath = "projects/\(project.id.uuidString)/drawings/\(drawingId.uuidString).pdf"
        _ = try await storage.child(storagePath).putFileAsync(from: destinationURL)

        let drawing = Drawing(id: drawingId, projectId: project.id, name: fileName, storagePath: storagePath, localURL: destinationURL, createdAt: Date())
        try await saveDrawingMetadata(drawing, for: project)

        await MainActor.run {
            self.drawings.append(drawing)
            self.activeDrawingId = drawing.id
        }
        return drawing
    }

    private func saveDrawingMetadata(_ drawing: Drawing, for project: Project) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "id": drawing.id.uuidString, "projectId": drawing.projectId.uuidString,
            "name": drawing.name, "storagePath": drawing.storagePath, "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(uid).collection("projects").document(project.id.uuidString)
            .collection("drawings").document(drawing.id.uuidString).setData(data)
    }

    func deleteDrawing(_ drawing: Drawing) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("projects").document(drawing.projectId.uuidString)
            .collection("drawings").document(drawing.id.uuidString).delete()
        storage.child(drawing.storagePath).delete { _ in }
        try? FileManager.default.removeItem(at: drawing.localURL)

        DispatchQueue.main.async {
            self.drawings.removeAll { $0.id == drawing.id }
            if self.activeDrawingId == drawing.id { self.activeDrawingId = nil }
        }
    }
}

// MARK: - Rooms & Scans
extension AppState {
    @discardableResult
        func createRoom(projectId: String, drawingId: UUID, name: String, pinX: Double, pinY: Double) -> Room {
            guard let uid = Auth.auth().currentUser?.uid else { fatalError("No User") }
            
            let roomId = UUID().uuidString
            let room = Room(
                id: roomId,
                projectId: projectId,
                drawingId: drawingId,
                name: name,
                pinX: pinX,
                pinY: pinY,
                createdAt: Date()
            )
            
            // 1. Prepare data for Firestore
            let data: [String: Any] = [
                "id": roomId,
                "projectId": projectId,
                "drawingId": drawingId.uuidString,
                "name": name,
                "pinX": pinX,
                "pinY": pinY,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            // 2. Save to the sub-collection under the project
            db.collection("users").document(uid)
                .collection("projects").document(projectId)
                .collection("rooms").document(roomId)
                .setData(data)
            
            // 3. Update local UI
            self.rooms.append(room)
            
            print("🟢 Room synced to Cloud: \(name)")
            return room
        }
    func loadRooms(for project: Project) {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            db.collection("users").document(uid)
                .collection("projects").document(project.id.uuidString)
                .collection("rooms")
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents else { return }
                    
                    let loadedRooms = documents.compactMap { doc -> Room? in
                        let data = doc.data()
                        guard let name = data["name"] as? String,
                              let drawingIdString = data["drawingId"] as? String,
                              let drawingId = UUID(uuidString: drawingIdString),
                              let pinX = data["pinX"] as? Double,
                              let pinY = data["pinY"] as? Double,
                              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                        
                        return Room(id: doc.documentID, projectId: project.id.uuidString, drawingId: drawingId, name: name, pinX: pinX, pinY: pinY, createdAt: createdAt)
                    }
                    
                    DispatchQueue.main.async {
                        self.rooms = loadedRooms
                        print("✅ Loaded \(loadedRooms.count) rooms/pins")
                    }
                }
        }

    
    func addScan(projectId: String, drawingId: String, roomId: String, images: [UIImage]) async {
        print("🚀 Starting sync for Room: \(roomId)")
        
        do {
            let scanId = UUID().uuidString
            var uploadedFileNames: [String] = []

            // 1. Try Storage Upload
            for (index, image) in images.enumerated() {
                let fileName = "photo_\(index).jpg"
                let storagePath = "projects/\(projectId)/drawings/\(drawingId)/rooms/\(roomId)/scans/\(scanId)/\(fileName)"
                let fileRef = storage.child(storagePath)

                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    print("❌ Failed to convert image \(index) to Data")
                    continue
                }

                print("📤 Attempting Storage upload: \(storagePath)")
                _ = try await fileRef.putDataAsync(imageData)
                uploadedFileNames.append(fileName)
                print("✅ Image \(index) uploaded successfully")
            }

            // 2. Try Firestore Save
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let scanData: [String: Any] = [
                "id": scanId,
                "projectId": projectId,
                "drawingId": drawingId,
                "roomId": roomId,
                "imageFileNames": uploadedFileNames,
                "capturedAt": Timestamp(date: Date()) // Use Firebase Timestamp
            ]

            print("📝 Attempting Firestore scan doc creation...")
            // NEW FLAT PATH (Reliable)
            try await db.collection("users").document(uid)
                .collection("scans").document(scanId)
                .setData(scanData)
                
            print("🎉 Sync complete for scan: \(scanId)")

        } catch {
            print("❌ CRITICAL SYNC ERROR: \(error.localizedDescription)")
        }
    }
    func loadAllProjectScans(projectId: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No User ID found")
            return
        }

        // Direct path: users -> UID -> scans
        // We filter by projectId inside this folder. No "Collection Group" needed.
        db.collection("users").document(uid).collection("scans")
            .whereField("projectId", isEqualTo: projectId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Permission/Query Error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let fetchedScans = documents.compactMap { doc -> Scan? in
                    try? doc.data(as: Scan.self)
                }

                DispatchQueue.main.async {
                    self.savedScans = fetchedScans
                    print("✅ Project Scans Synced: \(fetchedScans.count) total found for \(projectId)")
                }
            }
    }
    func scans(in room: Room) -> [Scan] {
        savedScans.filter { $0.roomId == room.id }.sorted { $0.capturedAt < $1.capturedAt }
    }
    
    func deleteRoom(_ room: Room) {
        rooms.removeAll { $0.id == room.id }
    }
}
