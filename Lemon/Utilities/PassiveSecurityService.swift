//
//  PassiveSecurityService.swift
//  Lemon
//
//  Created by antigravity on 11/02/2026.
//

import Foundation
import CoreMotion
import Combine

/// A battery-efficient security service that detects unauthorized movement using motion sensors.
class PassiveSecurityService: ObservableObject {
    static let shared = PassiveSecurityService()
    
    private let motionManager = CMMotionManager()
    private let vibrationThreshold: Double = 0.5 // G-force threshold for "tampering"
    private var isMonitoring = false
    
    @Published var isSuspiciousMovementDetected = false
    
    private init() {}
    
    /// Starts monitoring for suspicious movement when the scooter is locked.
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable && !isMonitoring else { return }
        
        isMonitoring = true
        motionManager.accelerometerUpdateInterval = 0.5 // 2Hz is enough for passive detection
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let acceleration = data.acceleration
            let totalG = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
            
            // Check for sudden movement or vibration (ignoring gravity which is 1.0)
            if abs(totalG - 1.0) > self.vibrationThreshold {
                self.handleSuspiciousMovement()
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
        isSuspiciousMovementDetected = false
    }
    
    private func handleSuspiciousMovement() {
        print("Security: ⚠️ Suspicious movement detected!")
        isSuspiciousMovementDetected = true
        
        // In a real app, this would token-report to the backend
        // for fleet monitoring without needing a full GPS lock immediately.
    }
}
