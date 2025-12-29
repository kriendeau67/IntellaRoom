import SwiftUI

struct ProjectCaptureView: View {
    let drawing: Drawing

    @EnvironmentObject var appState: AppState

    // Selected room when a green pin is tapped
    @State private var selectedRoom: Room?

    // Creating a new room
    @State private var pendingRoomName: String = ""
    @State private var pendingPinPoint: CGPoint?

    enum ActiveSheet: Identifiable {
        case roomPrompt
        case scanner(Room)

        var id: String {
            switch self {
            case .roomPrompt:
                return "roomPrompt"
            case .scanner(let room):
                return "scanner-\(room.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?


    var body: some View {
        ZStack {
            PDFKitView(
                url: drawing.url,
                rooms: appState.rooms,
                onAddScanAtPoint: { point in
                    pendingPinPoint = point
                    pendingRoomName = ""
                    activeSheet = .roomPrompt
                },
                selectedRoom: $selectedRoom
            )
            .ignoresSafeArea()
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
                            projectId: "demoProject",
                            pdfId: "demoPdf",
                            name: pendingRoomName,
                            pinX: point.x,
                            pinY: point.y
                        )

                        activeSheet = .scanner(room)
                    }
                )

            case .scanner(let room):
                ScannerView(room: room)
                    .environmentObject(appState)
            }
        }

        // Sheet 2 — tap room pin → see scans in that room
        .sheet(item: $selectedRoom) { room in
            RoomScansSheet(room: room)
                .environmentObject(appState)
        }
    }
}

private struct RoomScansSheet: View {
    let room: Room

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
                    appState.deleteRoom(room)
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
