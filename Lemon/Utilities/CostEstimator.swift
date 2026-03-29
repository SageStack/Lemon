//
//  CostEstimator.swift
//  Lemon
//
//  Created by antigravity on 11/02/2026.
//

import Foundation

/// A high-performance on-device cost estimator to sync with backend pricing logic.
struct CostEstimator {
    // These should ideally be synced from a Remote Config file
    static let BASE_UNLOCK_FEE = 100.0 // Rs. 100
    static let RATE_PER_MINUTE = 20.0  // Rs. 20

    /// Calculates the current estimated cost of a ride.
    /// - Parameter startTime: The date the ride started.
    /// - Returns: The estimated cost in Rs.
    static func estimateCost(startTime: Date) -> Double {
        let durationSeconds = max(0, Date().timeIntervalSince(startTime))
        let durationMinutes = ceil(durationSeconds / 60.0)
        return BASE_UNLOCK_FEE + (durationMinutes * RATE_PER_MINUTE)
    }
    
    /// Formats the cost for display.
    static func format(cost: Double) -> String {
        return "Rs. \(Int(cost))"
    }
}
