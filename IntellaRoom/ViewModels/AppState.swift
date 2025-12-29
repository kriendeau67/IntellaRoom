import SwiftUI
import Combine

final class AppState: ObservableObject {

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil

    // NEW: first-class rooms (green pins)
    @Published var rooms: [Room] = []

    // Scans always belong to a room
    @Published var savedScans: [Scan] = []
    @Published var projects: [Project] = []

    func createProject(name: String, foreman: String) -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            foreman: foreman,
            createdAt: Date()
        )
        projects.append(project)
        return project
    }

    // MARK: - Auth (placeholder)

    func login(username: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.currentUser = username
            self.isLoggedIn = true
        }
    }

    func logout() {
        self.currentUser = nil
        self.isLoggedIn = false
    }

    // MARK: - Room + Scan Lifecycle (NEW MODEL)

    /// Create a Room when the green pin is dropped.
    /// pinX/pinY should be normalized (0...1) relative to the PDF view.
    @discardableResult
    func createRoom(
        projectId: String,
        pdfId: String,
        name: String,
        pinX: Double,
        pinY: Double
    ) -> Room {
        let room = Room(
            id: UUID().uuidString,
            projectId: projectId,
            pdfId: pdfId,
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
        pdfId: String,
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
            pdfId: pdfId,
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
}
