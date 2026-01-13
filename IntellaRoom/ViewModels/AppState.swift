import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage


final class AppState: ObservableObject {
    private let db = Firestore.firestore()

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil

    // NEW: first-class rooms (green pins)
    @Published var rooms: [Room] = []

    // Scans always belong to a room
    @Published var savedScans: [Scan] = []
    @Published var projects: [Project] = []

    @Published var drawings: [Drawing] = []
    @Published var activeDrawingId: UUID?
    
    func drawings(for project: Project) -> [Drawing] {
        drawings.filter { $0.projectId == project.id }
    }
    
    @MainActor
    func ensureDrawingPDFExists(_ drawing: Drawing) async {
        let path = drawing.localURL.path

        if FileManager.default.fileExists(atPath: path) {
            print("📄 PDF already exists locally")
            return
        }

        print("⬇️ Downloading PDF from Storage")

        let ref = Storage.storage().reference(withPath: drawing.storagePath)

        do {
            try await ref.writeAsync(toFile: drawing.localURL)
            print("✅ PDF downloaded to:", drawing.localURL.path)
        } catch {
            print("❌ Failed to download PDF:", error.localizedDescription)
        }
    }
    func addDrawing(
        from pickedURL: URL,
        to project: Project
    ) async throws -> Drawing {

        guard pickedURL.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "DrawingImport", code: 1)
        }
        defer { pickedURL.stopAccessingSecurityScopedResource() }

        let drawingId = UUID()
        let fileName = pickedURL.deletingPathExtension().lastPathComponent

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let projectFolder = documents
            .appendingPathComponent("Projects")
            .appendingPathComponent(project.id.uuidString)
            .appendingPathComponent("Drawings", isDirectory: true)

        try FileManager.default.createDirectory(
            at: projectFolder,
            withIntermediateDirectories: true
        )

        let destinationURL = projectFolder
            .appendingPathComponent("\(drawingId.uuidString).pdf")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // ✅ Secure copy (your existing logic, unchanged)
        let coordinator = NSFileCoordinator()
        var readError: NSError?
        var writeError: NSError?

        coordinator.coordinate(
            readingItemAt: pickedURL,
            options: [],
            error: &readError
        ) { readableURL in
            do {
                let data = try Data(contentsOf: readableURL)
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                writeError = error as NSError
            }
        }

        if let error = readError { throw error }
        if let error = writeError { throw error }

        if !FileManager.default.fileExists(atPath: destinationURL.path) {
                    print("❌ Local File Error: The PDF was not found at \(destinationURL.path)")
                    throw NSError(domain: "LocalFile", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local PDF missing"])
                }
        
        // 🔴 NEW: Upload PDF to Firebase Storage
        // 1. Prepare the Storage Reference
        let storageRef = Storage.storage().reference().child("projects/\(project.id.uuidString)/drawings/\(drawingId.uuidString).pdf")

                // 2. Perform the Upload and WAIT for it to finish
                print("📤 Starting upload to: \(storageRef.fullPath)")
                _ = try await storageRef.putFileAsync(from: destinationURL)
                print("✅ Upload complete")

                // 3. Create the Drawing object ONLY after upload is successful
                let drawing = Drawing(
                    id: drawingId,
                    projectId: project.id,
                    name: fileName,
                    storagePath: storageRef.fullPath,
                    localURL: destinationURL,
                    createdAt: Date()
                )

                // 4. Save metadata to Firestore (Wait for this too)
        // 1. Upload Binary (Wait for success)
            _ = try await storageRef.putFileAsync(from: destinationURL)

            // 2. Save Metadata (Wait for success)
            // This now waits because we made the function async above
            try await saveDrawingMetadata(drawing, for: project)

            // 3. Update UI (Only after 1 and 2 are 100% finished)
            await MainActor.run {
                self.drawings.append(drawing)
                self.activeDrawingId = drawing.id
            }

                print("📄 Drawing fully synced & added to UI:", drawing.name)
                return drawing
    }
        
    
    func deleteDrawing(_ drawing: Drawing) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user — cannot delete drawing")
            return
        }

        let drawingRef = db
            .collection("users")
            .document(uid)
            .collection("projects")
            .document(drawing.projectId.uuidString)
            .collection("drawings")
            .document(drawing.id.uuidString)

        drawingRef.delete { error in
            if let error = error {
                print("❌ Failed to delete drawing from Firestore:", error.localizedDescription)
                return
            }

            DispatchQueue.main.async {
                // Remove local PDF file
                try? FileManager.default.removeItem(at: drawing.localURL)

                // Remove rooms + scans tied to this drawing
                self.rooms.removeAll { $0.drawingId == drawing.id }
                self.savedScans.removeAll {
                    self.room(for: $0)?.drawingId == drawing.id
                }

                // Remove drawing from local state
                self.drawings.removeAll { $0.id == drawing.id }

                // Clear active drawing if needed
                if self.activeDrawingId == drawing.id {
                    self.activeDrawingId = nil
                }

                print("🗑️ Drawing fully deleted:", drawing.name)
            }
        }
    }
    
    // Fetch Drawings from Firebase DB
    func loadDrawings(for project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user — cannot load drawings")
            return
        }

        print("📥 Loading drawings for project:", project.name)

        db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id.uuidString)
            .collection("drawings")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in

                if let error = error {
                    print("❌ Failed to load drawings:", error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No drawings found")
                    return
                }

                let loadedDrawings: [Drawing] = documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let name = data["name"] as? String,
                        let storagePath = data["storagePath"] as? String,
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    else {
                        print("⚠️ Skipping drawing (missing fields):", doc.documentID)
                        return nil
                    }

                    let drawingId = UUID(uuidString: doc.documentID) ?? UUID()
                    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

                    let localURL = documentsDir
                        .appendingPathComponent("Projects")
                        .appendingPathComponent(project.id.uuidString)
                        .appendingPathComponent("Drawings")
                        .appendingPathComponent("\(drawingId.uuidString).pdf")

                    return Drawing(
                        id: drawingId,
                        projectId: project.id,
                        name: name,
                        storagePath: storagePath,
                        localURL: localURL,
                        createdAt: createdAt
                    )
                }

                // ✅ UPDATE THE UI FIRST
                DispatchQueue.main.async {
                    self.drawings = loadedDrawings
                    print("✅ Loaded \(loadedDrawings.count) drawings metadata")
                    
                    // 🔴 THE MISSING PIECE:
                    // Now that the UI knows about the drawings, tell the device
                    // to download any PDFs that don't exist yet (like on your iPad).
                    Task {
                        for drawing in loadedDrawings {
                            await self.ensureDrawingPDFExists(drawing)
                        }
                    }
                }
            }
    }
    @discardableResult
    func createProject(name: String, foreman: String) -> Project {
        guard let uid = Auth.auth().currentUser?.uid else {
            fatalError("❌ Cannot create project without authenticated user")
        }

        let projectId = UUID()
        let project = Project(
            id: projectId,
            name: name,
            foreman: foreman,
            createdAt: Date()
        )

        let data: [String: Any] = [
            "name": name,
            "foreman": foreman,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("users")
            .document(uid)
            .collection("projects")
            .document(projectId.uuidString)
            .setData(data) { error in
                if let error = error {
                    print("❌ Failed to save project:", error.localizedDescription)
                } else {
                    print("💾 Project saved to Firestore:", project.name)
                }
            }

        projects.insert(project, at: 0)
        return project
    }
    func deleteProject(_ project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user — cannot delete project")
            return
        }

        let projectRef = db
            .collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id.uuidString)

        projectRef.delete { error in
            if let error = error {
                print("❌ Failed to delete project from Firestore:", error.localizedDescription)
                return
            }

            DispatchQueue.main.async {
                // Remove local PDFs folder for this project (safe even if missing)
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let projectFolder = documents
                    .appendingPathComponent("Projects")
                    .appendingPathComponent(project.id.uuidString)

                try? FileManager.default.removeItem(at: projectFolder)

                // Remove in-memory data
                self.projects.removeAll { $0.id == project.id }
                self.drawings.removeAll { $0.projectId == project.id }
                self.rooms.removeAll { $0.projectId == project.id.uuidString }
                // Remove scans whose room belonged to this project
                self.savedScans.removeAll { scan in
                    self.room(for: scan)?.projectId == project.id.uuidString
                }

                // Clear active drawing if it belonged to this project
                if let activeId = self.activeDrawingId,
                   self.drawings.first(where: { $0.id == activeId }) == nil {
                    self.activeDrawingId = nil
                }

                print("🗑️ Project fully deleted:", project.name)
            }
        }
    }
    private func saveDrawingMetadata(_ drawing: Drawing, for project: Project) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }

        // We use a dictionary that matches your Firestore structure
        let data: [String: Any] = [
            "id": drawing.id.uuidString,
            "projectId": drawing.projectId.uuidString,
            "name": drawing.name,
            "storagePath": drawing.storagePath,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let docRef = db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id.uuidString)
            .collection("drawings")
            .document(drawing.id.uuidString)

        // Using 'setData' with 'await' makes the code stop here until Firestore confirms success
        try await docRef.setData(data)
        print("💾 Firestore metadata confirmed saved for:", drawing.name)
    }


    

    // MARK: - Room + Scan Lifecycle (NEW MODEL)

    /// Create a Room when the green pin is dropped.
    /// pinX/pinY should be normalized (0...1) relative to the PDF view.
    @discardableResult
    func createRoom(
        projectId: String,
       // pdfId: String,
        drawingId: UUID,
        name: String,
        pinX: Double,
        pinY: Double
    ) -> Room {
        let room = Room(
            id: UUID().uuidString,
            projectId: projectId,
            drawingId: drawingId,
            name: name,
            pinX: pinX,
            pinY: pinY,
            createdAt: Date()
        )

        rooms.append(room)

        print("🟢 Room created: \(name) @ (\(pinX), \(pinY))")
        return room
    }

    /// Add a Scan to an existing Room.
    func addScan(
        projectId: String,
        roomId: String,
        imageFileNames: [String]
    ) {
        // Safety: prevent orphan scans
        guard rooms.contains(where: { $0.id == roomId }) else {
            assertionFailure("Attempted to add scan to non-existent roomId: \(roomId)")
            print("❌ Scan NOT saved — roomId not found: \(roomId)")
            return
        }

        let newScan = Scan(
            id: UUID().uuidString,
            projectId: projectId,
            roomId: roomId,
            imageFileNames: imageFileNames,
            capturedAt: Date()
        )

        savedScans.append(newScan)

        print("💾 Scan saved! roomId: \(roomId), Images: \(imageFileNames.count)")
    }
    func deleteRoom(_ room: Room) {
        // delete associated scan + images if needed
        rooms.removeAll { $0.id == room.id }
    }
    // MARK: - Helpers (useful for UI)

    func room(for scan: Scan) -> Room? {
        rooms.first(where: { $0.id == scan.roomId })
    }

    func scans(in room: Room) -> [Scan] {
        savedScans
            .filter { $0.roomId == room.id }
            .sorted { $0.capturedAt < $1.capturedAt }
    }
    
    func loadProjectsForCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user — cannot load projects")
            return
        }

        print("📥 Loading projects for user:", uid)

        db.collection("users")
            .document(uid)
            .collection("projects")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in

                if let error = error {
                    print("❌ Failed to load projects:", error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No project documents found")
                    return
                }

                let loadedProjects: [Project] = documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let name = data["name"] as? String,
                        let foreman = data["foreman"] as? String,
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    else {
                        return nil
                    }

                    return Project(
                        id: UUID(uuidString: doc.documentID) ?? UUID(),
                        name: name,
                        foreman: foreman,
                        createdAt: createdAt
                    )
                }

                DispatchQueue.main.async {
                    self.projects = loadedProjects
                    print("✅ Loaded \(loadedProjects.count) projects")
                }
            }
    }
}
