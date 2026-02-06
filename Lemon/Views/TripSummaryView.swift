//
//  TripSummaryView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct TripSummaryView: View {
    let duration: Int
    let cost: Double
    let scooterCount: Int
    let distance: Double
    var onDone: () -> Void
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.lemonPrimary)
                    
                    Text("RIDE COMPLETED")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                    
                    Text("Thank you for riding with Lemon!")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Receipt Card
                VStack(spacing: 25) {
                    HStack {
                        SummaryItem(label: "TOTAL COST", value: String(format: "Rs. %.2f", cost), isHighlight: true)
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        SummaryItem(label: "DURATION", value: timeString(from: duration))
                        Spacer()
                        SummaryItem(label: "SCOOTERS", value: "\(scooterCount)")
                        Spacer()
                        SummaryItem(label: "DISTANCE", value: String(format: "%.2f km", distance))
                    }
                }
                .padding(30)
                .background(Color.lemonDark)
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: onDone) {
                    Text("DONE")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.lemonPrimary)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            HapticManager.shared.notification(.success)
        }
    }
    
    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d min %d sec", minutes, remainingSeconds)
    }
}

struct SummaryItem: View {
    let label: String
    let value: String
    var isHighlight: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: isHighlight ? 32 : 18, weight: .bold, design: .monospaced))
                .foregroundColor(isHighlight ? .lemonPrimary : .white)
        }
    }
}
