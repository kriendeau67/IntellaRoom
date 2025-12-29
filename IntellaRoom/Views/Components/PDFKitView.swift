import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let url: URL

    let onAddScanAtPoint: (CGPoint) -> Void

    @Binding var savedScans: [Scan]
    @Binding var selectedScan: Scan?
    
    // 1. New Binding to tell parent what we clicked

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemGray6
        
        let interaction = UIContextMenuInteraction(delegate: context.coordinator)
        pdfView.addInteraction(interaction)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        pdfView.addGestureRecognizer(tapGesture)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.parent = self
        
        print("🔄 UPDATE-UI: Scans in AppState: \(savedScans.count)")

        guard let document = uiView.document,
              let page = document.page(at: 0) else { return }
        
        // Selective Delete (Keep Red Pins)
        for annotation in page.annotations {
            if annotation.userName == "SAVED_SCAN" {
                page.removeAnnotation(annotation)
            }
        }
        
        // Redraw Green Pins
        for scan in savedScans {
            let point = CGPoint(x: scan.x, y: scan.y)
            context.coordinator.addPin(at: point, on: page, color: .green, isSaved: true, scanID: scan.id)
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
            guard let pdfView = gesture.view as? PDFView else { return }
            guard let page = pdfView.currentPage else { return }
            
            let location = gesture.location(in: pdfView)
            let locationOnPage = pdfView.convert(location, to: page)
            
            if let annotation = page.annotation(at: locationOnPage) {
                // 2. CHECK IF IT'S A SAVED SCAN
                if let idString = annotation.contents,
                   let uuid = UUID(uuidString: idString) {
                    
                    print("👆 Found ID: \(uuid)")
                    
                    // 3. Find the actual Scan object in the list
                    if let foundScan = parent.savedScans.first(where: { $0.id == uuid }) {
                        // 4. Trigger the sheet!
                        parent.selectedScan = foundScan
                    }
                }
            }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {

            guard let pdfView = interaction.view as? PDFView else { return nil }
            guard let page = pdfView.page(for: location, nearest: true) else { return nil }
            let locationOnPage = pdfView.convert(location, to: page)

            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                UIMenu(title: "Room Options", children: [
                    UIAction(title: "Add Scan", image: UIImage(systemName: "camera.viewfinder")) { _ in
                        self.addPin(at: locationOnPage, on: page, color: .red, isSaved: false, scanID: nil)
                        self.parent.onAddScanAtPoint(locationOnPage)
                    },
                    UIAction(title: "Cancel", image: UIImage(systemName: "xmark"), attributes: .destructive) { _ in }
                ])
            }
        }
        
        func addPin(at point: CGPoint, on page: PDFPage, color: UIColor, isSaved: Bool, scanID: UUID?) {
            let bounds = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
            let annotation = PDFAnnotation(bounds: bounds, forType: .circle, withProperties: nil)
            annotation.color = color
            annotation.interiorColor = color.withAlphaComponent(0.5)
            
            if isSaved {
                annotation.userName = "SAVED_SCAN"
                if let id = scanID {
                    annotation.contents = id.uuidString
                }
            }
            
            page.addAnnotation(annotation)
        }
    }
}
