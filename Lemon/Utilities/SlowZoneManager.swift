//
//  SlowZoneManager.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 05/02/2026.
//

import Foundation
import CoreLocation

struct SlowZone: Identifiable {
    let id = UUID()
    let name: String
    let center: CLLocationCoordinate2D
    let radius: Double // meters
}

class SlowZoneManager {
    static let shared = SlowZoneManager()
    
    // Example zones (Colombo area)
    let slowZones = [
        SlowZone(name: "Galle Face Green", center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8436), radius: 300),
        SlowZone(name: "Viharamahadevi Park", center: CLLocationCoordinate2D(latitude: 6.9128, longitude: 79.8612), radius: 400)
    ]
    
    private var lastEnteredZoneId: UUID?
    
    func checkZone(location: CLLocation) -> SlowZone? {
        for zone in slowZones {
            let zoneLocation = CLLocation(latitude: zone.center.latitude, longitude: zone.center.longitude)
            if location.distance(from: zoneLocation) <= zone.radius {
                if lastEnteredZoneId != zone.id {
                    lastEnteredZoneId = zone.id
                    return zone
                }
                return nil // Already in this zone, don't re-trigger
            }
        }
        
        lastEnteredZoneId = nil
        return nil
    }
}
