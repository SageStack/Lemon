//
//  CameraManager.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import AVFoundation
import UIKit
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    @Published var permissionGranted = false
    
    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "com.lemon.cameraSessionQueue")
    
    private override init() {
        super.init()
        checkPermission()
        configureSession()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
    }
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
            
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                }
            } catch {
                print("Error creating video device input: \(error)")
                return
            }
            
            // Metadata output for QR (will be added by specific views if needed, or we can add it here generally)
            // For now, we keep it simple as a base session manager
            
            self.session.commitConfiguration()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}
