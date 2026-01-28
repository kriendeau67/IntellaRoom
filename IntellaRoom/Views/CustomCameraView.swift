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
    let onCapture: (Data) -> Void
    
    var body: some View {
        ZStack {
            // 1. The Camera Feed (Bottom Layer)
            GeometryReader { geometry in
                CameraPreview(session: camera.session)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            // 2. The Controls (Top Layer)
            VStack {
                // Cancel Button at the top
                HStack {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                }
                
                Spacer()
                
                // Lens Toggles (.5x and 1x)
                HStack(spacing: 20) {
                    Button(action: { camera.switchLens(to: .builtInUltraWideCamera) }) {
                        Text(".5x")
                            .font(.caption.bold())
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    Button(action: { camera.switchLens(to: .builtInWideAngleCamera) }) {
                        Text("1x")
                            .font(.caption.bold())
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 10)
                
                // SINGLE Shutter Button
                Button(action: { camera.capture() }) {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .frame(width: 70, height: 70)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.checkPermissions()
            
            // We now listen for the high-res Data instead of the shrunk Image
            camera.onDataCaptured = { [camera] rawData in
                onCapture(rawData) // Pass the raw bytes to AppState
                isPresented = false
            }
        }
        .onDisappear {
                    camera.stop()
                }
    }
    
    
    
    struct CameraPreview: UIViewRepresentable {
        let session: AVCaptureSession
        
        func makeUIView(context: Context) -> CameraVideoContainerView {
            let view = CameraVideoContainerView()
            view.session = session
            return view
        }
        
        func updateUIView(_ uiView: CameraVideoContainerView, context: Context) {}
    }
    
    // This is the special "Brain" that handles the rotation/spreading
    class CameraVideoContainerView: UIView {
        var session: AVCaptureSession? {
            get { (layer as? AVCaptureVideoPreviewLayer)?.session }
            set { (layer as? AVCaptureVideoPreviewLayer)?.session = newValue }
        }
        
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // This is the magic line that tells the feed to "spread" horizontally
            if let connection = (layer as? AVCaptureVideoPreviewLayer)?.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = currentVideoOrientation()
                }
            }
        }
        
        private func currentVideoOrientation() -> AVCaptureVideoOrientation {
            switch UIDevice.current.orientation {
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            case .portraitUpsideDown: return .portraitUpsideDown
            default: return .portrait
            }
        }
    }
}
