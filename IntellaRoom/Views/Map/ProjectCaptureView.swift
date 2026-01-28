import SwiftUI

struct ProjectCaptureView: View {
    let drawing: Drawing

    @EnvironmentObject var appState: AppState

    // Selected room when a green pin is tapped
    @State private var selectedRoom: Room?
    @State private var isPDFReady = false
    // Creating a new room
    @State private var pendingRoomName: String = ""
    @State private var pendingPinPoint: CGPoint?

    
    enum ActiveSheet: Identifiable {
        case roomPrompt
        case scanner(Room, Drawing)

        var id: String {
            switch self {
            case .roomPrompt:
                return "roomPrompt"
            case .scanner(let room, _):
                    return "scanner-\(room.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?


    var body: some View {
        ZStack {
            if isPDFReady {
                PDFKitView(
                    url: drawing.localURL,
                    // Filter rooms to only show pins for THIS drawing
                    rooms: appState.rooms.filter { $0.drawingId == drawing.id },
                    onAddScanAtPoint: { point in
                        pendingPinPoint = point
                        pendingRoomName = ""
                        activeSheet = .roomPrompt
                    },
                    selectedRoom: $selectedRoom
                )
                .ignoresSafeArea()
            } else {
                ProgressView("Loading drawing…")
            }
        }
        .task {
            // 1. Ensure the PDF is downloaded
            await appState.ensureDrawingPDFExists(drawing)
            
            // 2. NEW: Fetch the rooms/pins from Firestore so they appear on the iPad
            // We wrap this in a project check to get the ID
            if let project = appState.projects.first(where: { $0.id == drawing.projectId }) {
                appState.loadRooms(for: project)
            }
            
            isPDFReady = true
        }
        .navigationTitle("Floor Plan")
        .navigationBarTitleDisplayMode(.inline)

        // Sheet 1 — create room, then scan
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .roomPrompt:
                RoomNamePromptView(
                    roomName: $pendingRoomName,
                    onConfirm: {
                        guard let point = pendingPinPoint else { return }

                        let room = appState.createRoom(
                            projectId: drawing.projectId.uuidString,
                            drawingId: drawing.id,
                            name: pendingRoomName,
                            pinX: point.x,
                            pinY: point.y
                        )

                        activeSheet = .scanner(room, drawing)
                    }
                )

            case .scanner(let room, let drawing): // We now "catch" both pieces
                ScannerView(room: room, drawing: drawing) // Pass both to the scanner
                    .environmentObject(appState)
            }
        }

        // Sheet 2 — tap room pin → see scans in that room
        .sheet(item: $selectedRoom) { room in
            RoomScansSheet(room: room, drawing: self.drawing)
                .environmentObject(appState)
        }
    }
}

private struct RoomScansSheet: View {
    let room: Room
    let drawing: Drawing
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScan: Scan?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                let scans = appState.scans(in: room)

                if scans.isEmpty {
                    Text("No scans yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scans) { scan in
                        Button {
                            selectedScan = scan
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scan")
                                    .font(.headline)
                                Text("\(scan.imageFileNames.count) images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // We now load everything for the whole project at once
               // appState.loadAllProjectScans(projectId: room.projectId)
                appState.loadAllProjectScans(projectId: room.projectId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Room?", isPresented: $showDeleteConfirmation) {
                Button("Delete Room", role: .destructive) {
                  //  appState.deleteRoom(room)
                    appState.deleteRoom(room, drawingId: drawing.id.uuidString)
                    dismiss()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete the room and its scan. This action cannot be undone.")
            }
            .sheet(item: $selectedScan) { scan in
                ScanDetailView(scan: scan, room: room)
            }
        }
    }
}
