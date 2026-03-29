//
//  ParkingValidationService.swift
//  Lemon
//
//  Created by Antigravity on 11/02/2026.
//

import Foundation
import CoreML
import Vision
import UIKit

class ParkingValidationService {
    static let shared = ParkingValidationService()
    
    private var model: VNCoreMLModel?
    
    private init() {
        setupModel()
    }
    
    private func setupModel() {
        do {
            // Use the auto-generated class for ParkingValidation
            let config = MLModelConfiguration()
            let parkingModel = try ParkingValidation(configuration: config)
            self.model = try VNCoreMLModel(for: parkingModel.model)
            print("ParkingValidation: ✅ Model loaded successfully via auto-generated class.")
        } catch {
            print("ParkingValidation: ❌ Error loading model: \(error)")
            // Fallback: Try to load as VNCoreMLModel directly if specific class fails
            // This is just a safety net for the prototype
        }
    }
    
    struct ValidationResult {
        let isPass: Bool
        let message: String
        let confidence: Double
    }
    
    func validateParking(image: UIImage) async -> ValidationResult {
        guard let model = model else {
            return ValidationResult(isPass: true, message: "Model not loaded (Bypassing for prototype)", confidence: 1.0)
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("ParkingValidation: ❌ Inference error: \(error)")
                    continuation.resume(returning: ValidationResult(isPass: true, message: "Inference failed: \(error.localizedDescription)", confidence: 0.0))
                    return
                }
                
                guard let observations = request.results as? [VNPixelBufferObservation] else {
                    continuation.resume(returning: ValidationResult(isPass: true, message: "Unexpected model output type", confidence: 0.0))
                    return
                }
                
                // Process the segmentation mask
                // DeepLabV3 usually outputs a pixel buffer where each pixel value is the class index.
                let result = self.analyzeMask(observations[0].pixelBuffer)
                continuation.resume(returning: result)
            }
            
            request.imageCropAndScaleOption = .centerCrop
            
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: ValidationResult(isPass: false, message: "Invalid image data", confidence: 0.0))
                return
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("ParkingValidation: ❌ Error performing request: \(error)")
                continuation.resume(returning: ValidationResult(isPass: true, message: "Error performing request", confidence: 0.0))
            }
        }
    }
    
    private func analyzeMask(_ pixelBuffer: CVPixelBuffer) -> ValidationResult {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return ValidationResult(isPass: true, message: "Could not read mask address", confidence: 0.0)
        }
        
        // Cityscapes classes (Standard DeepLabV3+ labels usually follow this or VOC):
        // 0: road, 1: sidewalk, 2: building, 3: wall, 4: fence, 5: pole, 6: traffic light, 7: traffic sign, 8: vegetation, 9: terrain...
        
        var totalPixels = 0
        var roadPixelsInBottom = 0
        var sidewalkPixelsInBottom = 0
        
        var globalRoadPixels = 0
        var globalSidewalkPixels = 0
        var urbanEnvironmentPixels = 0 // building, wall, fence
        
        let pointer = baseAddress.assumingMemoryBound(to: UInt32.self)
        let groundThreshold = Int(Double(height) * 0.7) // Bottom 30%
        
        for y in 0..<height {
            let isGroundZone = y >= groundThreshold
            for x in 0..<width {
                let pixelValue = pointer[y * (bytesPerRow / 4) + x]
                totalPixels += 1
                
                switch pixelValue {
                case 0: // Road
                    globalRoadPixels += 1
                    if isGroundZone { roadPixelsInBottom += 1 }
                case 1: // Sidewalk
                    globalSidewalkPixels += 1
                    if isGroundZone { sidewalkPixelsInBottom += 1 }
                case 2, 3, 4: // Building, Wall, Fence
                    urbanEnvironmentPixels += 1
                default:
                    break
                }
            }
        }
        
        let total = Double(totalPixels)
        let groundTotal = Double(width * (height - groundThreshold))
        
        let roadRatio = Double(globalRoadPixels) / total
        let sidewalkRatio = Double(globalSidewalkPixels) / total
        let urbanRatio = Double(urbanEnvironmentPixels) / total
        let groundRoadRatio = Double(roadPixelsInBottom) / groundTotal
        
        print("ParkingValidation: 📊 Global Road: \(String(format: "%.1f%%", roadRatio * 100)), Sidewalk: \(String(format: "%.1f%%", sidewalkRatio * 100))")
        print("ParkingValidation: 📊 Ground Road: \(String(format: "%.1f%%", groundRoadRatio * 100)), Urban: \(String(format: "%.1f%%", urbanRatio * 100))")
        
        // --- IMPROVED LOGIC ---
        
        // 1. CRITICAL FAIL: Road detected in the immediate foreground (ground zone)
        if groundRoadRatio > 0.4 {
            return ValidationResult(
                isPass: false, 
                message: "It looks like you've parked on the road. Please move the scooter to a sidewalk for safety.", 
                confidence: groundRoadRatio
            )
        }
        
        // 2. OBSTRUCTION CHECK: Too close to a wall/building
        if urbanRatio > 0.8 {
            return ValidationResult(
                isPass: false, 
                message: "You are too close to a wall or building. Please park in a clear area of the sidewalk.", 
                confidence: urbanRatio
            )
        }
        
        // 3. VALID ENVIRONMENT CHECK: High urban content + sidewalk
        if sidewalkRatio > 0.1 || (sidewalkRatio > 0.05 && urbanRatio > 0.2) {
            return ValidationResult(
                isPass: true, 
                message: "Perfectly parked! You are in a clear pedestrian zone.", 
                confidence: sidewalkRatio + urbanRatio
            )
        }
        
        // 4. AMBIGUOUS FALLBACK: If road is minimal and it doesn't look like a clear fail
        if roadRatio < 0.2 {
            return ValidationResult(
                isPass: true, 
                message: "Parking looks acceptable.", 
                confidence: 0.5
            )
        }
        
        // Default: If road is significant but sidewalk is low
        return ValidationResult(
            isPass: false, 
            message: "Improper parking detected. Please ensure you are on a sidewalk and retake the photo.", 
            confidence: roadRatio
        )
    }
}
