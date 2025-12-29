import SwiftUI

struct ScannerView: View {
    let room: Room

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {

            let imageCount = Int.random(in: 2...4)
            var fileNames: [String] = []

            for index in 1...imageCount {
                let fileName = "scan-\(UUID().uuidString)-wall-\(index).jpg"
                savePlaceholderImage(named: fileName)
                fileNames.append(fileName)
            }

            appState.addScan(
                projectId: room.projectId,
                pdfId: room.pdfId,
                roomId: room.id,
                imageFileNames: fileNames
            )

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
