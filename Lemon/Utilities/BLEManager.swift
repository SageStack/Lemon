//
//  BLEManager.swift
//  Lemon
//
//  Created by antigravity on 11/02/2026.
//

import Foundation
import CoreBluetooth
import Combine

/// Mocks the Bluetooth Low Energy (BLE) interaction for Optimistic Unlocking.
/// In a real production app, this would use CBCentralManager to connect to the scooter's hardware.
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = BLEManager()
    
    @Published var isScanning = false
    @Published var connectedScooterId: String?
    
    private var centralManager: CBCentralManager!
    
    private override init() {
        super.init()
        // We initialize but don't start scanning until requested to save battery
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func unlockScooterOptimistically(id: String) async -> Bool {
        print("BLE: 📡 Attempting optimistic local handshake with scooter \(id)...")
        
        // Mocking the BLE latency (usually < 200ms vs 1-3s for Cloud)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Success 95% of the time in our mock
        let success = Double.random(in: 0...1) < 0.95
        
        if success {
            print("BLE: ✅ Local handshake SUCCESS for \(id). Propagating status upgrade.")
            DispatchQueue.main.async {
                self.connectedScooterId = id
            }
        } else {
            print("BLE: ⚠️ Local handshake failed or out of range. Falling back to Cloud-only.")
        }
        
        return success
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("BLE: 🆗 Bluetooth is powered on.")
        case .poweredOff:
            print("BLE: 🛑 Bluetooth is powered off.")
        default:
            break
        }
    }
}
