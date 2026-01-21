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

        // 1. DELETE FLAT SCAN DOCUMENTS & STORAGE FILES
        // We use the scans currently in memory to wipe both DB and Storage
        let scansToDelete = savedScans.filter { $0.projectId == projectIdString }
        for scan in scansToDelete {
            // Delete each physical file in this scan
            for fileName in scan.imageFileNames {
                let storagePath = "projects/\(projectIdString)/drawings/\(scan.drawingId)/rooms/\(scan.roomId)/scans/\(scan.id)/\(fileName)"
                storage.child(storagePath).delete { _ in }
                
                // Delete local file
                let localURL = scan.getLocalURL(for: fileName)
                try? FileManager.default.removeItem(at: localURL)
            }
            // Delete the scan record from the flat collection
            db.collection("users").document(uid).collection("scans").document(scan.id).delete()
        }

        // 2. DELETE SUB-COLLECTIONS (Rooms & Drawings)
        // Firestore requires us to delete every document in a sub-collection individually
        let projectRef = db.collection("users").document(uid).collection("projects").document(projectIdString)
        
        // Clear Rooms
        projectRef.collection("rooms").getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }
        
        // Clear Drawings
        projectRef.collection("drawings").getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }

        // 3. DELETE THE ACTUAL PROJECT DOCUMENT
        projectRef.delete { error in
            if let error = error { print("❌ Project Delete Error: \(error.localizedDescription)") }
        }

        // 4. LOCAL FOLDER CLEANUP (PDFs/Drawings)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectFolder = documents.appendingPathComponent(projectIdString) // Adjusted path
        try? FileManager.default.removeItem(at: projectFolder)

        // 5. UPDATE UI STATE
        DispatchQueue.main.async {
            self.projects.removeAll { $0.id == project.id }
            self.drawings.removeAll { $0.projectId == project.id }
            self.rooms.removeAll { $0.projectId == projectIdString }
            self.savedScans.removeAll { $0.projectId == projectIdString }
            
            if self.activeDrawingId != nil && self.drawings.isEmpty {
                self.activeDrawingId = nil
            }
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
        // --- REPLACE THE db PATH IN createRoom WITH THIS ---
        db.collection("users").document(uid)
            .collection("projects").document(projectId)
            .collection("drawings").document(drawingId.uuidString) // Added this layer
            .collection("rooms").document(roomId)
            .setData(data)
        
        // 3. Update local UI
        self.rooms.append(room)
        
        print("🟢 Room synced to Cloud: \(name)")
        return room
    }
    func loadRooms(for project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // --- UPDATED: Search for ANY room collection belonging to this project ---
        db.collectionGroup("rooms")
            .whereField("projectId", isEqualTo: project.id.uuidString)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Room Load Error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let loadedRooms = documents.compactMap { doc -> Room? in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let drawingIdString = data["drawingId"] as? String,
                          let drawingId = UUID(uuidString: drawingIdString),
                          let pinX = data["pinX"] as? Double,
                          let pinY = data["pinY"] as? Double,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                    
                    return Room(
                        id: doc.documentID,
                        projectId: project.id.uuidString,
                        drawingId: drawingId,
                        name: name,
                        pinX: pinX,
                        pinY: pinY,
                        createdAt: createdAt
                    )
                }
                
                DispatchQueue.main.async {
                    self.rooms = loadedRooms
                    print("✅ Loaded \(loadedRooms.count) rooms/pins from nested hierarchy")
                }
            }
    }
    
    
    func addScan(projectId: String, drawingId: String, roomId: String, images: [UIImage]) async {
        print("🚀 Starting Local Save for Room: \(roomId)")
        
        let scanId = UUID().uuidString
        var localFileNames: [String] = []
        
        // --- STEP 1: SAVE TO IPHONE HARD DRIVE (Immediate) ---
        for (index, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 1.0) {                let fileName = "\(scanId)_photo_\(index).jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                
                do {
                    try data.write(to: url)
                    localFileNames.append(fileName)
                    print("💾 Saved photo locally: \(fileName)")
                    
                    // --- ADD THIS RIGHT AFTER: try data.write(to: url) ---

                    let thumbName = fileName.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
                    let thumbUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(thumbName)

                    let thumbnail = createThumbnail(from: image)
                    if let thumbData = thumbnail.jpegData(compressionQuality: 0.6) {
                        try? thumbData.write(to: thumbUrl)
                        print("💾 Saved thumbnail locally: \(thumbName)")
                    }
                    
                } catch {
                    print("❌ Local Save Error: \(error.localizedDescription)")
                }
            }
        }
        
        // Create the object using our local files
        let newScan = Scan(
            id: scanId,
            projectId: projectId,
            drawingId: drawingId, // Ensure your Scan struct uses 'drawingId' (fixed the 'q')
            roomId: roomId,
            imageFileNames: localFileNames,
            capturedAt: Date()
        )
        
        // --- STEP 2: UPDATE SCREEN INSTANTLY ---
        // This makes the photo show up in the app without needing a signal
        DispatchQueue.main.async {
            self.savedScans.append(newScan)
            print("✅ UI Updated with local scan data")
        }
        
        // --- STEP 3: SYNC TO CLOUD (Background) ---
        // We wrap this in a 'do-catch' so if the cloud fails, the local data stays safe
        do {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            // A. Upload to Storage
            for fileName in localFileNames {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                let storagePath = "projects/\(projectId)/drawings/\(drawingId)/rooms/\(roomId)/scans/\(scanId)/\(fileName)"
                let fileRef = storage.child(storagePath)
                
                print("📤 Syncing to Cloud Storage: \(fileName)")
                _ = try await fileRef.putFileAsync(from: url) // Syncing the file we just saved
                
                let thumbName = fileName.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
                let thumbUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(thumbName)
                let thumbStoragePath = "projects/\(projectId)/drawings/\(drawingId)/rooms/\(roomId)/scans/\(scanId)/\(thumbName)"
                let thumbRef = storage.child(thumbStoragePath)
                print("📤 Syncing Thumbnail to Cloud: \(thumbName)")
            }
            
            // B. Save to Database (Flat Path)
            let scanData: [String: Any] = [
                "id": scanId,
                "projectId": projectId,
                "drawingId": drawingId,
                "roomId": roomId,
                "imageFileNames": localFileNames,
                "capturedAt": Timestamp(date: Date()),
                "userId": uid // Added for security rules
            ]
            
            // --- REPLACE THE db PATH IN addScan WITH THIS ---
            try await db.collection("users").document(uid)
                .collection("projects").document(projectId)
                .collection("drawings").document(drawingId) // Added this layer
                .collection("rooms").document(roomId)
                .collection("scans").document(scanId)
                .setData(scanData)
            // This toggles the 'isUploaded' status in your UI immediately
            DispatchQueue.main.async {
                if let index = self.savedScans.firstIndex(where: { $0.id == scanId }) {
                    self.savedScans[index].isUploaded = true
                }
            }
            
            print("🎉 Cloud Sync complete for scan: \(scanId)")
            
        } catch {
            // If this prints, the photo is STILL on the phone, just not the cloud yet
            print("⚠️ Background Sync Delayed (No Signal?): \(error.localizedDescription)")
        }
    }
    func loadAllProjectScans(projectId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collectionGroup("scans")
            .whereField("userId", isEqualTo: uid)
            .whereField("projectId", isEqualTo: projectId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Query Error: \(error.localizedDescription)")
                    return
                }
                
                // 1. Check if ANY raw data came back from the cloud
                print("DEBUG: Raw documents found in cloud: \(snapshot?.documents.count ?? 0)")
                
                let fetchedScans = snapshot?.documents.compactMap { doc -> Scan? in
                    let decodedScan = try? doc.data(as: Scan.self)
                    
                    // 2. Check if the app is struggling to turn the cloud data into a Scan struct
                    if decodedScan == nil {
                        print("❌ DEBUG: Failed to decode document ID: \(doc.documentID)")
                    }
                    
                    return decodedScan
                } ?? []
                
                DispatchQueue.main.async {
                    self.savedScans = fetchedScans
                    // 3. Confirm what the UI is actually receiving
                    print("✅ DEBUG: self.savedScans updated. Count: \(self.savedScans.count)")
                }
            }
    }
    func scans(in room: Room) -> [Scan] {
        savedScans.filter { $0.roomId == room.id }.sorted { $0.capturedAt < $1.capturedAt }
    }
    
    func deleteRoom(_ room: Room) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1. DELETE ROOM FROM FIRESTORE
        db.collection("users").document(uid)
            .collection("projects").document(room.projectId)
            .collection("rooms").document(room.id)
            .delete() { error in
                if let error = error { print("❌ Room Delete Error: \(error.localizedDescription)") }
            }

        // 2. DELETE SCANS, CLOUD IMAGES, AND LOCAL IMAGES
        db.collection("users").document(uid).collection("scans")
            .whereField("roomId", isEqualTo: room.id)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    if let scan = try? doc.data(as: Scan.self) {
                        for fileName in scan.imageFileNames {
                            // --- A. DELETE FROM CLOUD STORAGE ---
                            let storagePath = "projects/\(scan.projectId)/drawings/\(scan.drawingId)/rooms/\(scan.roomId)/scans/\(scan.id)/\(fileName)"
                            self.storage.child(storagePath).delete { _ in }

                            // --- B. DELETE FROM IPHONE HARD DRIVE ---
                            let localURL = scan.getLocalURL(for: fileName)
                            try? FileManager.default.removeItem(at: localURL)
                            print("🗑️ Local file removed: \(fileName)")
                        }
                    }
                    // --- C. DELETE SCAN RECORD FROM FIRESTORE ---
                    doc.reference.delete()
                }
            }

        // 3. LOCAL UI CLEANUP
        DispatchQueue.main.async {
            self.rooms.removeAll { $0.id == room.id }
            self.savedScans.removeAll { $0.roomId == room.id }
        }
    }
    // Resize Pano to Thumbnail
    func createThumbnail(from image: UIImage, targetSize: CGSize = CGSize(width: 400, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
