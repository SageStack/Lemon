//
//  Scooter.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import Foundation
import MapKit

struct Scooter: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var name: String?
    var latitude: Double
    var longitude: Double
    var batteryPercentage: Int?
    var isAvailable: Bool?
    var isLocked: Bool?
    var reservedBy: String?
    var status: String?
    var lastUpdated: Date?
    var alarmActive: Bool?
    var geohash: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var rangeKm: Double {
        Double(batteryPercentage ?? 0) * 0.4 // 100% = 40km
    }
    
    var pricePerMin: String {
        "LKR 25"
    }
    
    var displayName: String {
        name ?? "Lemon Scooter"
    }
    
    var displayBattery: Int {
        batteryPercentage ?? 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case batteryPercentage = "battery_percentage"
        case isLocked = "is_locked"
        case isAvailable = "is_available"
        case reservedBy = "reserved_by"
        case status
        case lastUpdated = "last_updated"
        case alarmActive = "alarm_active"
        case geohash
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         latitude: Double, 
         longitude: Double, 
         batteryPercentage: Int = 100, 
         isLocked: Bool = true, 
         isAvailable: Bool = true, 
         status: String = "idle", 
         lastUpdated: Date? = Date(),
         alarmActive: Bool = false,
         geohash: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.batteryPercentage = batteryPercentage
        self.isLocked = isLocked
        self.isAvailable = isAvailable
        self.status = status
        self.lastUpdated = lastUpdated
        self.alarmActive = alarmActive
        self.geohash = geohash
    }
}
