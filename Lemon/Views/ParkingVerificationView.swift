import SwiftUI
import AVFoundation
import FirebaseStorage

struct ParkingVerificationView: View {
    @Binding var isVisible: Bool
    @Binding var isActiveRide: Bool
    let scooterIds: [String]
    let rideData: (duration: Int, cost: Double, count: Int, distance: Double)?
    let userId: String?
    
    @State private var currentScooterIndex = 0
    @State private var isCaptured = false
    @State private var shutterEffect = false
    @State private var sessionRunning = true
    
    // Logic fault: Check for empty IDs
    @State private var uploadedPhotoUrl: String?
    @State private var isUploading = false
    
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
                
                VStack(spacing: 8) {
                    Text(isCaptured ? "PHOTO CAPTURED" : "PARKING VERIFICATION")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.lemonPrimary)
                    
                    if scooterIds.count > 1 {
                        Text("Scooter \(currentScooterIndex + 1) of \(scooterIds.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Text(isCaptured ? (isUploading ? "Uploading verification..." : "Great! Verification uploaded.") : "Please take a photo of scooter \(scooterIds.count > 0 ? (scooterIds[safe: currentScooterIndex] ?? "selected") : "selected") parked correctly.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Camera Viewfinder
                ZStack {
                    CameraCaptureView(isSessionRunning: $sessionRunning)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )
                    
                    if shutterEffect {
                        Color.white
                            .cornerRadius(20)
                            .transition(.opacity)
                    }
                    
                    if isCaptured {
                        ZStack {
                            Color.black.opacity(0.4)
                            if isUploading {
                                ProgressView()
                                    .tint(.lemonPrimary)
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.lemonPrimary)
                            }
                        }
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                if isCaptured && !isUploading {
                    if isLastScooter {
                        Button(action: {
                            Task {
                                do {
                                    guard let photoUrl = uploadedPhotoUrl else { return }
                                    // Secure Backend Call: End Ride & Calculate Cost
                                    let loc = LocationManager.shared.userLocation?.coordinate
                                    try await ScooterService.shared.endRide(scooterIds: scooterIds, latitude: loc?.latitude ?? 0, longitude: loc?.longitude ?? 0, photoUrl: photoUrl)
                                    
                                    await MainActor.run {
                                        withAnimation {
                                            isActiveRide = false
                                            isVisible = false
                                        }
                                    }
                                } catch {
                                    print("Lock failed: \(error)")
                                }
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
                            withAnimation {
                                currentScooterIndex += 1
                                isCaptured = false
                                uploadedPhotoUrl = nil
                                sessionRunning = true
                            }
                        }) {
                            Text("NEXT SCOOTER")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.white)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal, 30)
                    }
                } else if !isCaptured {
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
        withAnimation(.easeInOut(duration: 0.1)) {
            shutterEffect = true
        }
        
        // Real Capture
        let delegate = PhotoCaptureDelegate { result in
            switch result {
            case .success(let data):
                uploadPhoto(data: data)
            case .failure(let error):
                print("Capture failed: \(error)")
            }
        }
        
        CameraManager.shared.capturePhoto(delegate: delegate)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shutterEffect = false
            }
            
            AudioServicesPlaySystemSound(1108) // Shutter sound
            withAnimation(.spring()) {
                isCaptured = true
                sessionRunning = false
            }
        }
    }
    
    private func uploadPhoto(data: Data) {
        isUploading = true
        let storageRef = FirebaseManager.shared.storage.reference().child("parking_verification/\(userId ?? "unknown")/\(UUID().uuidString).jpg")
        
        storageRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                print("Upload failed: \(error)")
                isUploading = false
                return
            }
            
            storageRef.downloadURL { url, error in
                isUploading = false
                if let url = url {
                    self.uploadedPhotoUrl = url.absoluteString
                }
            }
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void
    
    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion(.failure(NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data"])))
            return
        }
        
        completion(.success(imageData))
    }
}
}

// Helper extension for safe array indexing
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
