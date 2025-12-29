import SwiftUI

struct ScanDetailView: View {
    let scan: Scan

    @State private var selectedIndex: Int = 0

    // Helper: reconstruct file URLs from filenames
    private var imageURLs: [URL] {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return scan.imageFileNames.map { documents.appendingPathComponent($0) }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scan.date)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                    .padding(.top, 12)

                Text(scan.roomName)
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
                Label("PDF Location: (\(scan.x), \(scan.y))", systemImage: "map")
                Label("Wall Images: \(scan.imageFileNames.count)", systemImage: "square.grid.2x2")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            // Wall image viewer
            if imageURLs.isEmpty {
                Spacer()
                Text("No images captured")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        ZoomableImage(url: url)
                            .tag(index)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                Text("Wall \(selectedIndex + 1) of \(imageURLs.count)")
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
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { _ in
            Group {
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
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
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("Image missing")
                            .foregroundColor(.secondary)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.03))
            .cornerRadius(12)
        }
        .frame(height: 420) // keeps sheet layout stable
    }
}
