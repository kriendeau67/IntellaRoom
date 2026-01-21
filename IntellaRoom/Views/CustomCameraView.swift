//
//  CustomCameraView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 1/21/26.
//

import SwiftUI
import AVFoundation

import SwiftUI

struct CustomCameraView: View {
    @StateObject var camera = CameraManager()
    @Binding var isPresented: Bool
    var onCapture: (UIImage) -> Void // We stay with UIImage for now to keep it simple

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.white).padding()
                    Spacer()
                }
                Spacer()
                Button(action: { camera.capture() }) {
                    Circle().fill(Color.white).frame(width: 70, height: 70)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.checkPermissions()
            
            // THE FIX: Access the manager through the state object specifically
            camera.onImageCaptured = { [camera] uiImage in
                onCapture(uiImage)
                isPresented = false
            }
        }
    }
}

// The bridge between UIKit's PreviewLayer and SwiftUI
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
