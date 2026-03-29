//
//  QRScannerView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    var onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        controller.metadataDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, QRScannerViewControllerDelegate, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerView
        
        init(parent: QRScannerView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            parent.onScan(code)
        }
        
        // MARK: - AVCaptureMetadataOutputObjectsDelegate
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            CameraManager.shared.stopSession()
            
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                DispatchQueue.main.async { [weak self] in
                    self?.didScanCode(stringValue)
                }
            }
        }
    }
}

protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerViewControllerDelegate?
    weak var metadataDelegate: AVCaptureMetadataOutputObjectsDelegate?
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupSession()
    }
    
    private func setupSession() {
        let session = CameraManager.shared.session
        let metaDelegate = self.metadataDelegate // Capture on Main Thread
        
        // Add Metadata Output if not present
        // Check needs to be somewhat safe or we rely on CameraManager to perform this one-time setup
        // For robustnes: We'll dispatch to sessionQueue to check and add.
        
        CameraManager.shared.sessionQueue.async {
            session.beginConfiguration()
            
            let metadataOutput: AVCaptureMetadataOutput
            if let existingOutput = session.outputs.first(where: { $0 is AVCaptureMetadataOutput }) as? AVCaptureMetadataOutput {
                metadataOutput = existingOutput
            } else {
                metadataOutput = AVCaptureMetadataOutput()
                if session.canAddOutput(metadataOutput) {
                    session.addOutput(metadataOutput)
                } else {
                    session.commitConfiguration()
                    return
                }
            }
            
            if let metaDelegate = metaDelegate {
                metadataOutput.setMetadataObjectsDelegate(metaDelegate, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
            session.commitConfiguration()
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    func failed() {
        // Handle failure
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CameraManager.shared.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraManager.shared.stopSession()
    }
    
    // Delegate conformance moved to Coordinator
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func startScanning() {
        CameraManager.shared.startSession()
    }
    
    func stopScanning() {
        CameraManager.shared.stopSession()
    }
}
