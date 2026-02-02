//
//  ScooterCard.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct ScooterCard: View {
    let scooter: Scooter
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scooter.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(scooter.pricePerMin) per minute")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 15) {
                    Label("\(Int(scooter.rangeKm)) km", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                    Label("\(scooter.displayBattery)%", systemImage: "bolt.fill")
                        .foregroundColor(scooter.displayBattery < 20 ? .red : .lemonPrimary)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ReserveScooter"), object: scooter)
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("RESERVE")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                }
                
                ActionButton(title: "UNLOCK", icon: "qrcode.viewfinder") {
                    NotificationCenter.default.post(name: NSNotification.Name("UnlockScooter"), object: nil)
                }
            }
        }
        .padding(24)
        .background(Color.lemonDark) // FIXED: Matches the extension name
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
