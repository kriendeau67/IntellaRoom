import SwiftUI

struct ScannerView: View {
    let room: Room
    let drawing: Drawing
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // NEW: State to hold the captured photo and show the camera
        @State private var inputImage: UIImage?
        @State private var showCamera = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Scanning \(room.name)")
                .font(.title2)
                .bold()

            Text("Pin: (\(room.pinX), \(room.pinY))")
                .font(.caption)
                .foregroundStyle(.secondary)

            // UPDATED: Now opens the real camera instead of simulating
                        Button(action: { showCamera = true }) {
                            Label("Open Camera", systemImage: "camera.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
        }
        .padding()
        // NEW: This triggers the actual camera view
        .sheet(isPresented: $showCamera) {
            // We pass the binding so the camera can dismiss itself
            CustomCameraView(isPresented: $showCamera) { capturedUIImage in
                // This updates the variable that your .onChange is watching
                self.inputImage = capturedUIImage
            }
        }
        // Keep your existing .onChange exactly as it is
        .onChange(of: inputImage) { _ , newImage in
            if let newImage = newImage {
                saveRealScan(image: newImage)
            }
        }
    }


    private func saveRealScan(image: UIImage) {
            Task {
                await appState.addScan(
                    projectId: room.projectId,
                    drawingId: drawing.id.uuidString,
                    roomId: room.id,
                    images: [image] // The actual photo from the camera!
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
