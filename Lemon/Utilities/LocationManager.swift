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
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        
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
