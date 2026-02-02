import SwiftUI
import AVFoundation

struct ParkingVerificationView: View {
    @Binding var isVisible: Bool
    @Binding var isActiveRide: Bool
    @State private var isCaptured = false
    @State private var shutterEffect = false
    @State private var sessionRunning = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Button(action: { isVisible = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                Text(isCaptured ? "PHOTO CAPTURED" : "PARKING VERIFICATION")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.lemonPrimary)
                
                Text("Please take a photo of the scooter parked correctly to end your ride.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Camera Viewfinder
                ZStack {
                    // Real Camera Preview
                    CameraCaptureView(isSessionRunning: $sessionRunning)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )
                    
                    // Shutter Effect
                    if shutterEffect {
                        Color.white
                            .cornerRadius(20)
                            .transition(.opacity)
                    }
                    
                    if isCaptured {
                        // Success Overlay
                        ZStack {
                            Color.black.opacity(0.4)
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.lemonPrimary)
                        }
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                if isCaptured {
                    Button(action: {
                        withAnimation {
                            isActiveRide = false
                            isVisible = false
                        }
                    }) {
                        Text("FINISH RIDE")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.lemonPrimary)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 30)
                } else {
                    Button(action: {
                        capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onDisappear {
            sessionRunning = false
        }
    }
    
    private func capturePhoto() {
        // Trigger shutter effect
        withAnimation(.easeInOut(duration: 0.1)) {
            shutterEffect = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shutterEffect = false
            }
            
            // Mock capture success
            AudioServicesPlaySystemSound(1108) // Shutter sound
            withAnimation(.spring()) {
                isCaptured = true
                sessionRunning = false // Stop session to save battery/power
            }
        }
    }
}
