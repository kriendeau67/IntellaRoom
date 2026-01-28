import SwiftUI

import SwiftUI

struct ScannerView: View {
    let room: Room
    let drawing: Drawing
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // UPDATED: Now holds Data instead of UIImage to preserve resolution
    @State private var capturedData: Data?
    @State private var showCamera = false
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text(isSaving ? "Saving High-Res Scan..." : "Scanning \(room.name)")
                .font(.title2)
                .bold()

            if isSaving {
                            // Show a more prominent spinner during the upload
                            ProgressView()
                                .controlSize(.large)
                            Text("Preserving full detail...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Pin: (\(room.pinX), \(room.pinY))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ProgressView("Opening Camera...")
                        }
                    }
                    .padding()
        // --- STEP 1: AUTO-OPEN CAMERA ---
                    .onAppear {
                                // Only auto-open if we haven't already captured data
                                if capturedData == nil {
                                    showCamera = true
                                }
                            }
        
        .sheet(isPresented: $showCamera) {
            // UPDATED: The closure now receives Data (rawData)
            CustomCameraView(isPresented: $showCamera) { rawData in
                self.isSaving = true
                self.capturedData = rawData
            }
        }
        // UPDATED: Watching for capturedData changes
        .onChange(of: capturedData) { _ , newData in
            if let data = newData {
                saveRealScan(data: data)
            }
        }
    }

    // UPDATED: Processes Data and includes roomName for the filename
    private func saveRealScan(data: Data) {
        Task {
            await appState.addScan(
                projectId: room.projectId,
                drawingId: drawing.id.uuidString,
                roomId: room.id,
                roomName: room.name,      // NEW: Added the room name here
                scanDataItems: [data]     // NEW: Renamed parameter to scanDataItems
            )
            dismiss()
        }
    }
}
// Open camera
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .camera

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator // This requires the Coordinator below
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image"]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // This class MUST act as the delegate for the picker to work
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
