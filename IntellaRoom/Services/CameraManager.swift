import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    
    // This is the specific variable the View is looking for
    var onImageCaptured: ((UIImage) -> Void)?

    func checkPermissions() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            setupCamera()
        } else {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.setupCamera() }
            }
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                     ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        guard let device = device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.onImageCaptured?(image)
            }
        }
    }
}
