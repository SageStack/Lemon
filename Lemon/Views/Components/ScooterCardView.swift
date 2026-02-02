//
//  ScooterCardView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct ScooterCardView: View {
    let scooter: Scooter
    var onUnlock: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(scooter.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(scooter.pricePerMin + " per min")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("\(scooter.displayBattery)%")
                }
                .foregroundColor(scooter.displayBattery > 20 ? .lemonPrimary : .red)
                .font(.system(.subheadline, design: .rounded).bold())
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            Text("Ready for pickup in Colombo 03")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.lemonDark)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.lemonPrimary.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
