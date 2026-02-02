//
//  RideHistoryView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct RideHistoryView: View {
    @Environment(\.dismiss) var dismiss
    
    let history = [
        RideRecord(date: "Today", distance: "2.4 km", cost: "Rs. 450", duration: "12 min"),
        RideRecord(date: "Yesterday", distance: "1.8 km", cost: "Rs. 320", duration: "8 min"),
        RideRecord(date: "Jan 4", distance: "4.2 km", cost: "Rs. 850", duration: "25 min"),
        RideRecord(date: "Jan 2", distance: "0.5 km", cost: "Rs. 150", duration: "3 min")
    ]
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("RIDE HISTORY")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().frame(width: 40).opacity(0)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(history) { ride in
                            RideHistoryRow(ride: ride)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct RideRecord: Identifiable {
    let id = UUID()
    let date: String
    let distance: String
    let cost: String
    let duration: String
}

struct RideHistoryRow: View {
    let ride: RideRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.date)
                    .font(.system(size: 14, weight: .bold))
                Text("\(ride.distance) • \(ride.duration)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text(ride.cost)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.lemonPrimary)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
