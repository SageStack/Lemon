//
//  ActiveRideView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import Combine
import CoreLocation

struct ActiveRideView: View {
    @Binding var isActive: Bool
    let scooterIds: [String]
    let allScooters: [Scooter]
    
    @State private var rideDuration = 0
    @State private var rideCost: Double = 0.0
    @State private var totalDistance: Double = 0.0
    @State private var lastLocation: CLLocation?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Computed property to get actual scooter objects
    private var activeScooters: [Scooter] {
        allScooters.filter { scooterIds.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if activeScooters.isEmpty && !scooterIds.isEmpty {
                    // Fallback if data is still loading
                    Text("Loading scooters...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    ForEach(activeScooters) { scooter in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(activeScooters.count > 1 ? "ACTIVE SCOOTER" : "ACTIVE RIDE")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.lemonPrimary)
                                Text(scooter.displayName)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                Text("\(scooter.displayBattery)%")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.lemonPrimary)
                        }
                        if scooter.id != activeScooters.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                RideStatView(label: "TIME", value: timeString(from: rideDuration))
                Spacer()
                RideStatView(label: "COST", value: String(format: "Rs. %.2f", rideCost))
                Spacer()
                RideStatView(label: "DISTANCE", value: String(format: "%.2f km", totalDistance))
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("RequestAddScooter"), object: nil)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("ADD ANOTHER SCOOTER")
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.lemonPrimary)
                    .cornerRadius(15)
                }
                
                Button(action: {
                    let earliestStart = activeScooters.compactMap { $0.currentRideStart }.min() ?? Date()
                    let duration = Int(Date().timeIntervalSince(earliestStart))
                    let durationMinutes = ceil(Double(duration) / 60.0)
                    let baseCost = 100.0 * Double(max(1, activeScooters.count))
                    let timeCost = durationMinutes * 20.0 * Double(max(1, activeScooters.count))
                    let finalCost = baseCost + timeCost
                    
                    let tripData = TripData(
                        duration: duration,
                        cost: finalCost,
                        count: scooterIds.count,
                        distance: totalDistance
                    )
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RequestEndRide"), 
                        object: tripData
                    )
                }) {
                    Text("END RIDE")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(15)
                }
            }
        }
        .padding(24)
        .background(Color.lemonDark)
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onReceive(timer) { _ in
            // Start High-Precision tracking
            let startTimes = activeScooters.compactMap { $0.currentRideStart }
            let earliestStart = startTimes.min() ?? Date()
            
            let duration = Int(Date().timeIntervalSince(earliestStart))
            rideDuration = max(0, duration)
            
            // Use Centralized Cost Estimator for "Edge Truth"
            let estimate = CostEstimator.estimateCost(startTime: earliestStart)
            // Multiply by scooter count if group ride
            let multiEstimate = estimate * Double(max(1, activeScooters.count))
            
            withAnimation(.linear) {
                rideCost = multiEstimate
            }
        }
        .onReceive(LocationManager.shared.$userLocation) { newLocation in
             guard let loc = newLocation else { return }
             if let last = lastLocation {
                 let distanceDelta = loc.distance(from: last) / 1000.0 // Convert to km
                 if distanceDelta < 0.5 { // Simple noise filter (<500m jumps)
                     totalDistance += distanceDelta
                 }
             }
             lastLocation = loc
        }
    }
    
    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct RideStatView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
        }
    }
}
