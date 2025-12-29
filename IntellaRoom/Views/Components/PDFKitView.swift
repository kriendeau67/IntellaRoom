import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let url: URL
    let rooms: [Room]
    let onAddScanAtPoint: (CGPoint) -> Void

    @Binding var selectedRoom: Room?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6

        let interaction = UIContextMenuInteraction(delegate: context.coordinator)
        pdfView.addInteraction(interaction)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        pdfView.addGestureRecognizer(tapGesture)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.parent = self

        guard let document = uiView.document,
              let page = document.page(at: 0) else { return }

        // Remove existing saved room pins
        for annotation in page.annotations {
            if annotation.userName == "SAVED_ROOM" {
                page.removeAnnotation(annotation)
            }
        }

        // Draw green pins for rooms
        for room in rooms {
            let point = CGPoint(x: room.pinX, y: room.pinY)
            context.coordinator.addPin(
                at: point,
                on: page,
                color: .green,
                isSaved: true,
                roomID: room.id
            )
        }

        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        var parent: PDFKitView

        init(parent: PDFKitView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView,
                  let page = pdfView.currentPage else { return }

            let location = gesture.location(in: pdfView)
            let locationOnPage = pdfView.convert(location, to: page)

            if let annotation = page.annotation(at: locationOnPage),
               annotation.userName == "SAVED_ROOM",
               let roomId = annotation.contents {
                parent.selectedRoom = parent.rooms.first { $0.id == roomId }
            }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {

            guard let pdfView = interaction.view as? PDFView,
                  let page = pdfView.page(for: location, nearest: true) else {
                return nil
            }

            let locationOnPage = pdfView.convert(location, to: page)

            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                UIMenu(title: "Room Options", children: [
                    UIAction(
                        title: "Add Scan",
                        image: UIImage(systemName: "camera.viewfinder")
                    ) { _ in
                         
                        self.parent.onAddScanAtPoint(locationOnPage)
                    },
                    UIAction(
                        title: "Cancel",
                        image: UIImage(systemName: "xmark"),
                        attributes: .destructive
                    ) { _ in }
                ])
            }
        }

        func addPin(
            at point: CGPoint,
            on page: PDFPage,
            color: UIColor,
            isSaved: Bool,
            roomID: String?
        ) {
            let bounds = CGRect(
                x: point.x - 10,
                y: point.y - 10,
                width: 20,
                height: 20
            )

            let annotation = PDFAnnotation(
                bounds: bounds,
                forType: .circle,
                withProperties: nil
            )

            annotation.color = color
            annotation.interiorColor = color.withAlphaComponent(0.5)

            if isSaved {
                annotation.userName = "SAVED_ROOM"
                annotation.contents = roomID
            }

            page.addAnnotation(annotation)
        }
    }
}
