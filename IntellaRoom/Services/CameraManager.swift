import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    var onDataCaptured: ((Data) -> Void)?
    // This is the specific variable the View is looking for
  //  var onImageCaptured: ((UIImage) -> Void)?

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
        if session.canSetSessionPreset(.photo) {
                session.sessionPreset = .photo
            }
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                     ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        guard let device = device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.isHighResolutionCaptureEnabled = true // This is the "Master" high-res switch
            output.maxPhotoQualityPrioritization = .quality
        }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.photoQualityPrioritization = .quality
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
   
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // 1. Get the original, uncompressed bytes from the sensor
        guard let data = photo.fileDataRepresentation() else { return }
        print("📸 Raw Data Captured: \(data.count) bytes") // This should show a big number (e.g., 5,000,000+)
        // 2. Send these raw bytes directly to your saving logic
        DispatchQueue.main.async {
            // We will need to update AppState to accept 'Data' instead of 'UIImage'
            self.onDataCaptured?(data)
        }
    }
    func switchLens(to type: AVCaptureDevice.DeviceType) {
        session.beginConfiguration()
        
        // 1. Remove current input
        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }
        
        // 2. Select the new physical lens
        let newDevice = AVCaptureDevice.default(type, for: .video, position: .back)
        
        guard let device = newDevice,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        
        // 3. Plug in the new lens
        session.addInput(input)
        session.commitConfiguration()
    }
}
