//
//  ParkingVerificationView.swift
//  Lemon
//
//  Created by Antigravity on 11/02/2026.
//

import SwiftUI
import UIKit
import CoreLocation

struct ParkingVerificationView: View {
    @Binding var isVisible: Bool
    @Binding var isActiveRide: Bool
    let scooterIds: [String]
    let rideData: TripData?
    let userId: String?
    
    @State private var showingCamera = true
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var validationResult: ParkingValidationService.ValidationResult?
    @State private var error: String?
    @State private var currentScooterIndex = 0
    
    private var isLastScooter: Bool {
        scooterIds.isEmpty || currentScooterIndex >= scooterIds.count - 1
    }
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            if isProcessing {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.lemonPrimary)
                    Text("VALIDATING PARKING...")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.lemonPrimary)
                }
            } else if let errorMessage = error {
                VStack(spacing: 30) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    VStack(spacing: 12) {
                        Text("ERROR OCCURRED")
                            .font(.system(size: 24, weight: .black))
                        
                        Text(errorMessage)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: {
                        finishRide()
                    }) {
                        Text("RETRY FINISH RIDE")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.lemonPrimary)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        self.error = nil
                        self.validationResult = nil
                        self.capturedImage = nil
                        self.showingCamera = true
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding()
                    }
                }
            } else if let result = validationResult {
                VStack(spacing: 30) {
                    Image(systemName: result.isPass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(result.isPass ? .green : .red)
                    
                    VStack(spacing: 12) {
                        Text(result.isPass ? "PARKING APPROVED" : "IMPROPER PARKING")
                            .font(.system(size: 24, weight: .black))
                        
                        Text(result.message)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer().frame(height: 20)
                    
                    if result.isPass {
                        Button(action: {
                            finishRide()
                        }) {
                            Text("FINISH RIDE")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.lemonPrimary)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Button(action: {
                            validationResult = nil
                            capturedImage = nil
                            showingCamera = true
                        }) {
                            Text("RETAKE PHOTO")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .transition(.opacity)
            } else if let image = capturedImage {
                VStack(spacing: 20) {
                    Text("Please take a photo of \(scooterIds.count > 1 ? "scooter \(currentScooterIndex + 1) " : "the scooter ")parked correctly.")
                        .font(.custom("Outfit-Bold", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(20)
                        .padding()
                    
                    Button(action: {
                        validateImage(image)
                    }) {
                        Text("VERIFY PARKING")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.lemonPrimary)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        capturedImage = nil
                        showingCamera = true
                    }) {
                        Text("RETAKE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
    }
    
    private func validateImage(_ image: UIImage) {
        isProcessing = true
        Task {
            let result = await ParkingValidationService.shared.validateParking(image: image)
            await MainActor.run {
                withAnimation {
                    self.validationResult = result
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func finishRide() {
        guard let data = rideData else { 
            print("ParkingVerification: ❌ Missing ride data, cannot finish ride.")
            self.error = "Error: Missing ride data. Please contact support."
            return 
        }
        
        isProcessing = true
        self.error = nil
        
        Task {
            do {
                try await ScooterService.shared.endRide(
                    scooterIds: scooterIds,
                    latitude: LocationManager.shared.userLocation?.coordinate.latitude ?? 0,
                    longitude: LocationManager.shared.userLocation?.coordinate.longitude ?? 0,
                    totalDistanceKm: data.distance
                )
                await MainActor.run {
                    self.isProcessing = false
                    withAnimation {
                        isActiveRide = false
                        isVisible = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.error = error.localizedDescription
                    print("ParkingVerification: ❌ End Ride Failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Simple Camera Picker wrapper
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
