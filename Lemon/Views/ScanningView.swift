//
//  ScanningView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import AVFoundation

struct ScanningView: View {
    @Binding var isScanning: Bool
    @Binding var isActiveRide: Bool
    @Binding var activeScooterIds: [String]
    @State private var scanProgress: CGFloat = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera Layer
            if !isProcessing {
                QRScannerView(isScanning: $isScanning) { code in
                    // Synchronous lock to prevent multiple Task triggers
                    guard !isProcessing else { return }
                    
                    print("Scanned code: \(code)")
                    
                    // Trigger haptic on successful scan
                    HapticManager.shared.impact(.medium)
                    
                    // Logic fault check: Prevent scanning of duplicate IDs in the same session
                    if activeScooterIds.contains(code) {
                        errorMessage = "Scooter already added to ride."
                        showingError = true
                        return
                    }
                    
                    isProcessing = true
                    
                    Task {
                        do {
                            // In a real app, we'd fetch the scooter first to check is_locked
                            // But for this simulation, we'll try to unlock it.
                            let loc = LocationManager.shared.userLocation?.coordinate
                            try await ScooterService.shared.unlockScooter(id: code, latitude: loc?.latitude ?? 0, longitude: loc?.longitude ?? 0)
                            
                            // Trigger success haptic on unlock
                            HapticManager.shared.notification(.success)
                            
                            await MainActor.run {
                                withAnimation {
                                    activeScooterIds.append(code)
                                    isActiveRide = true
                                    isScanning = false
                                    isProcessing = false
                                }
                            }
                        } catch {
                            print("Unlock failed: \(error.localizedDescription)")
                            await MainActor.run {
                                errorMessage = "Unlock failed. Please try again."
                                showingError = true
                                isProcessing = false
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: 40) {
                HStack {
                    Button(action: { isScanning = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                Text(isProcessing ? "UNLOCKING..." : "SCAN QR CODE")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.lemonPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Scanning Box
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.lemonPrimary, lineWidth: 2)
                        .frame(width: 250, height: 250)
                    
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .lemonPrimary))
                            .scaleEffect(2)
                    } else {
                        // Scanning Line
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .lemonPrimary, .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 230, height: 2)
                            .offset(y: scanProgress)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                                    scanProgress = 100
                                }
                            }
                    }
                }
                .frame(width: 250, height: 250)
                
                Text(isProcessing ? "Verifying scooter..." : "Center the QR code on the scooter within the frame")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Flashlight Button (Optional enhancement)
                if !isProcessing {
                    Button(action: {
                        toggleTorch()
                    }) {
                        Image(systemName: "flashlight.on.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .alert("Status", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                if device.torchMode == .on {
                    device.torchMode = .off
                } else {
                    try device.setTorchModeOn(level: 1.0)
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        }
    }
}
