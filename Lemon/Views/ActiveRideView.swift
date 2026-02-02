//
//  ActiveRideView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine

struct ActiveRideView: View {
    @Binding var isActive: Bool
    @State private var rideDuration = 0
    @State private var rideCost: Double = 0.0
    @State private var activeScooters: [ScooterInfo] = [
        ScooterInfo(name: "Lemon Pro S1", battery: 85),
    ]
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    struct ScooterInfo: Identifiable {
        let id = UUID()
        let name: String
        let battery: Int
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(activeScooters) { scooter in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(activeScooters.count > 1 ? "ACTIVE SCOOTER" : "ACTIVE RIDE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.lemonPrimary)
                            Text(scooter.name)
                                .font(.system(size: 18, weight: .bold))
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                            Text("\(scooter.battery)%")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.lemonPrimary)
                    }
                    if scooter.id != activeScooters.last?.id {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                RideStatView(label: "TIME", value: timeString(from: rideDuration))
                Spacer()
                RideStatView(label: "COST", value: String(format: "Rs. %.2f", rideCost))
                Spacer()
                RideStatView(label: "DISTANCE", value: "0.2 km")
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
                    NotificationCenter.default.post(name: NSNotification.Name("RequestEndRide"), object: (rideDuration, rideCost, activeScooters.count))
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
            rideDuration += 1
            rideCost = Double(rideDuration) * 0.5 * Double(activeScooters.count) 
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestAddScooter"))) { _ in
            if activeScooters.count < 5 {
                withAnimation {
                    activeScooters.append(ScooterInfo(name: "Lemon Pro S\(activeScooters.count + 1)", battery: Int.random(in: 70...95)))
                }
            }
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
