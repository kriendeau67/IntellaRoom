import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

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
    
    func addDrawing(
        from pickedURL: URL,
        to project: Project
    ) throws -> Drawing {

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

        try FileManager.default.copyItem(
            at: pickedURL,
            to: destinationURL
        )

        let drawing = Drawing(
            id: drawingId,
            projectId: project.id,
            name: fileName,
            localURL: destinationURL,
            createdAt: Date()
        )

        drawings.append(drawing)

        print("📄 Drawing added:", drawing.name)
        return drawing
    }
    
    func deleteDrawing(_ drawing: Drawing) {
        // Remove file
        try? FileManager.default.removeItem(at: drawing.localURL)

        // Remove rooms + scans tied to this drawing
        rooms.removeAll { $0.drawingId == drawing.id }
        savedScans.removeAll {
            room(for: $0)?.drawingId == drawing.id
        }

        // Remove drawing
        drawings.removeAll { $0.id == drawing.id }

        if activeDrawingId == drawing.id {
            activeDrawingId = nil
        }

        print("🗑️ Drawing deleted:", drawing.name)
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
