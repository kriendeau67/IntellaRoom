import SwiftUI
import FirebaseStorage

struct ScanDetailView: View {
    let scan: Scan
    let room: Room
    @State private var selectedIndex: Int = 0

    // Helper: reconstruct file URLs from filenames
  /*  private var imageURLs: [URL] {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return scan.imageFileNames.map { documents.appendingPathComponent($0) }
    } */
    
    private var fileNames: [String] {
            scan.imageFileNames
        }
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scan.capturedAt)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                    .padding(.top, 12)

                Text(scan.roomId)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Scanned \(formattedDate)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Metadata
            VStack(alignment: .leading, spacing: 10) {
               // Label("Wall Images: \(scan.imageFileNames.count)", systemImage: "square.grid.2x2")
                Label("PDF Location: (\(room.pinX), \(room.pinY))",
                    systemImage: "map"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            // Wall image viewer
            if fileNames.isEmpty {
                Spacer()
                Text("No images captured")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                TabView(selection: $selectedIndex) {
                                    ForEach(Array(fileNames.enumerated()), id: \.offset) { index, fileName in
                                        // We pass the fileName and the scan object directly
                                        ZoomableImage(url: scan.getLocalURL(for: fileName), scan: scan)
                                            .tag(index)
                                            .padding(.horizontal)
                                    }
                                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                Text("Wall \(selectedIndex + 1) of \(fileNames.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Simple zoom/pan image viewer (no third-party deps)
struct ZoomableImage: View {
    let url: URL
    let scan: Scan // 2. We need the scan object to build the cloud path
    
    @State private var uiImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isLoading = false

    var body: some View {
        GeometryReader { _ in
            Group {
                if let image = uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .animation(.easeInOut(duration: 0.12), value: scale)
                } else if isLoading {
                    ProgressView("Downloading from Cloud...")
                } else {
                    // This shows if both local and cloud fail
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("Image missing")
                        Text(url.lastPathComponent).font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.03))
            .cornerRadius(12)
        }
        .frame(height: 420)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        // A. Try Local First
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            self.uiImage = image
            return
        }

        // B. Fallback to Cloud (for the iPad)
        isLoading = true
        let fileName = url.lastPathComponent
        let storagePath = "projects/\(scan.projectId)/drawings/\(scan.drawingId)/rooms/\(scan.roomId)/scans/\(scan.id)/\(fileName)"
        let storageRef = Storage.storage().reference().child(storagePath)

        print("☁️ iPad fetching from Cloud: \(storagePath)")

        storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
            isLoading = false
            if let data = data, let image = UIImage(data: data) {
                // Save it locally so the iPad has it for next time
                try? data.write(to: url)
                
                DispatchQueue.main.async {
                    self.uiImage = image
                }
            } else {
                print("❌ Cloud Download Failed: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
}
