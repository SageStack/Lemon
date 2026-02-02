//
//  CameraCaptureView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var isSessionRunning: Bool
    
    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {
        if isSessionRunning {
            uiViewController.startSession()
        } else {
            uiViewController.stopSession()
        }
    }
}

class CameraCaptureViewController: UIViewController {
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        let session = CameraManager.shared.session
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // If we needed photo output, we'd add it here similar to QRScannerView
        // For 'Photo Verification', we likely need AVCapturePhotoOutput
        CameraManager.shared.sessionQueue.async {
             session.beginConfiguration()
             if !session.outputs.contains(where: { $0 is AVCapturePhotoOutput }) {
                 let photoOutput = AVCapturePhotoOutput()
                 if session.canAddOutput(photoOutput) {
                     session.addOutput(photoOutput)
                 }
             }
             session.commitConfiguration()
        }
        
        // Start session on appear
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CameraManager.shared.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraManager.shared.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func startSession() {
        CameraManager.shared.startSession()
    }
    
    func stopSession() {
        CameraManager.shared.stopSession()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
