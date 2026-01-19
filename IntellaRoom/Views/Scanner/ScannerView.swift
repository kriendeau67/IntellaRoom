import SwiftUI

struct ScannerView: View {
    let room: Room
    let drawing: Drawing
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Scanning \(room.name)")
                .font(.title2)
                .bold()

            Text("Pin: (\(room.pinX), \(room.pinY))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Simulate Scan") {
                simulateScan()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }


    private func simulateScan() {
        // Since addScan is now "async", we wrap it in a Task
        Task {
            // 1. Create a fake "Image" to simulate a real photo
            // In the next step, we'll swap this for the real camera
            let mockImage = UIImage(systemName: "camera.shutter.button.fill") ?? UIImage()
            
            // 2. Call the new addScan logic
            await appState.addScan(
                projectId: room.projectId,
                drawingId: drawing.id.uuidString, // We use the drawing we passed in!
                roomId: room.id,
                images: [mockImage] // Sending a real image object
            )
            
            // 3. Close the scanner and go back to the map
            dismiss()
        }
    }

    private func savePlaceholderImage(named fileName: String) {
        let size = CGSize(width: 1600, height: 2400)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let text = "PLACEHOLDER WALL IMAGE"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)
        }

        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url)
        }
    }
}
