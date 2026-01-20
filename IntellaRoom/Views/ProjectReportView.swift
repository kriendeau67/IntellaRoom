import SwiftUI
import FirebaseStorage

struct ProjectReportView: View {
    @EnvironmentObject var appState: AppState
    @State private var reportSelection: ScanReportSelection?

    var body: some View {
        List {
            if appState.rooms.isEmpty {
                ContentUnavailableView(
                    "No Rooms Yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Rooms and scans will appear here once captured.")
                )
            } else {
                ForEach(appState.rooms) { room in
                    Section {
                        let scans = appState.scans(in: room)

                        if scans.isEmpty {
                            Text("No scans in this room")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(scans) { scan in
                                Button {
                                    // Capture EVERYTHING into one stable object immediately
                                    reportSelection = ScanReportSelection(
                                        id: scan.id,
                                        scan: scan,
                                        room: room
                                    )
                                    print("🎯 Stable selection captured for: \(scan.id)")
                                } label: {
                                    HStack(spacing: 12) {
                                        // --- NEW: THUMBNAIL ADDED HERE ---
                                        if let firstImage = scan.imageFileNames.first {
                                            ScanReportThumbnail(scan: scan, fileName: firstImage)
                                                .frame(width: 50, height: 50)
                                                .cornerRadius(6)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Scan")
                                                .font(.headline)

                                            Text("\(scan.imageFileNames.count) images")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            let scans = appState.scans(in: room)
                            Text("\(scans.count) scan\(scans.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reportSelection) { selection in
            // No more 'appState.find' or 'if let room' logic needed here.
            // The data is already inside the 'selection' object.
            ScanDetailView(scan: selection.scan, room: selection.room)
        }
    }
}




// Helper View for the List Thumbnail
struct ScanReportThumbnail: View {
    let scan: Scan
    let fileName: String
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        Group {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Color.gray.opacity(0.2)
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        // Same smart logic: Local First, then Cloud
        let localURL = scan.getLocalURL(for: fileName)
        if let data = try? Data(contentsOf: localURL), let image = UIImage(data: data) {
            self.thumbnail = image
            return
        }

        let storagePath = "projects/\(scan.projectId)/drawings/\(scan.drawingId)/rooms/\(scan.roomId)/scans/\(scan.id)/\(fileName)"
        let storageRef = Storage.storage().reference().child(storagePath)

        storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let data = data, let image = UIImage(data: data) {
                try? data.write(to: localURL)
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
}
