//
//  LocationManager.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import Foundation
import CoreLocation
import Combine
import UIKit // Required for ObservableObject and @Published

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    
    private var lastUpdateDate: Date = Date()
    private var currentSpeed: CLLocationSpeed = 0
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // 10 meters default
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    /// Lowers accuracy and frequency to save battery when user is stationary or traveling fast (not on a scooter).
    func applyAdaptiveSettings(for speed: CLLocationSpeed) {
        if speed < 0.5 { // Stationary
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = 50 
        } else if speed > 10 { // Traveling fast (likely in a car, not a scooter)
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = 200
        } else { // Optimal scooter/walking speed
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 10
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        currentSpeed = location.speed
        
        // Intelligent Pulse: Adjust sampling based on movement
        applyAdaptiveSettings(for: location.speed)
        
        
        // Smart Notification: Entering a Slow Zone
        if let zone = SlowZoneManager.shared.checkZone(location: location) {
            NotificationManager.shared.sendImmediateNotification(
                title: "Entering Slow Zone",
                body: "You're entering \(zone.name). Speed limited for safety.",
                identifier: "slow_zone_\(zone.id)"
            )
            HapticManager.shared.notification(.warning)
        }
    }
}
