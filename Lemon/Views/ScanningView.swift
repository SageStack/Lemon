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
    @State private var scanProgress: CGFloat = 0
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera Layer
            QRScannerView(isScanning: $isScanning) { code in
                print("Scanned code: \(code)")
                // In a real app, validate the code here
                isActiveRide = true
                isScanning = false
            }
            .ignoresSafeArea()
            
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
                
                Text("SCAN QR CODE")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.lemonPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Scanning Box
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.lemonPrimary, lineWidth: 2)
                        .frame(width: 250, height: 250)
                    
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
                .frame(width: 250, height: 250)
                
                Text("Center the QR code on the scooter within the frame")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Flashlight Button (Optional enhancement)
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
