import SwiftUI

struct ProjectMapView: View {
    @EnvironmentObject var appState: AppState
    
    // 1. State for CREATING a new scan
  //  @State private var scanTarget: ScanTarget?
    
    // 2. State for VIEWING an existing scan
    @State private var selectedScan: Scan?
    @State private var pendingRoomName: String = ""
 //   @State private var isShowingRoomPrompt = false
    
    enum ActiveSheet: Identifiable {
        case roomPrompt
        case scanner(ScanTarget)

        var id: String {
            switch self {
            case .roomPrompt: return "roomPrompt"
            case .scanner(let target): return "scanner-\(target.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
  //  @State private var pendingRoomName: String = ""
    @State private var pendingTarget: ScanTarget?
    
    private let pdfUrl = Bundle.main.url(forResource: "sample", withExtension: "pdf")

    var body: some View {
        ZStack {
            if let url = pdfUrl {
                PDFKitView(
                    url: url,
                    onAddScanAtPoint: { point in
                        // Store the target
                        pendingTarget = ScanTarget(point: point, roomName: "")
                        pendingRoomName = ""
                        activeSheet = .roomPrompt
                    },
                    savedScans: $appState.savedScans,
                    selectedScan: $selectedScan
                )
                .ignoresSafeArea()
            } else {
                Text("File not found")
            }
        }
        .navigationTitle("Floor Plan")
        .navigationBarTitleDisplayMode(.inline)
        
        // Sheet 1: The Scanner (Creation)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .roomPrompt:
                RoomNamePromptView(
                    roomName: $pendingRoomName,
                    onConfirm: {
                        guard let target = pendingTarget else { return }

                        let updatedTarget = ScanTarget(
                            point: target.point,
                            roomName: pendingRoomName
                        )

                        pendingTarget = updatedTarget
                        activeSheet = .scanner(updatedTarget)
                    }
                )

            case .scanner(let target):
                ScannerView(
                    roomName: target.roomName,
                    x: Int(target.point.x),
                    y: Int(target.point.y)
                )
            }
        }
        
        // Sheet 2: The Detail View (Viewing)
        .sheet(item: $selectedScan) { scan in
            ScanDetailView(scan: scan)
        }
    }
}
