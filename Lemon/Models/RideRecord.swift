//
//  RideRecord.swift
//  Lemon
//
//  Created by Antigravity on 05/02/2026.
//

import Foundation

struct RideRecord: Identifiable, Codable {
    let id: String
    let userId: String
    let date: Date
    let distanceKm: Double
    let cost: Double
    let durationSeconds: Int
    let scooterCount: Int
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var displayDuration: String {
        let minutes = durationSeconds / 60
        return "\(minutes) min"
    }
    
    var displayCost: String {
        return String(format: "Rs. %.0f", cost)
    }
    
    var displayDistance: String {
        return String(format: "%.1f km", distanceKm)
    }
}
