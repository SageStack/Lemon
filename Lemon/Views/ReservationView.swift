//
//  ReservationView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine

struct ReservationView: View {
    let scooter: Scooter
    @Binding var isReserved: Bool
    @State private var timeRemaining = 600 // 10 minutes
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 25) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RESERVED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.lemonPrimary)
                    Text(scooter.displayName)
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                Text(timeString(from: timeRemaining))
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.lemonPrimary)
            }
            
            Text("Your scooter is reserved for 10 minutes. Please find it on the map and scan to start your ride.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 15) {
                Button(action: {
                    withAnimation {
                        isReserved = false
                    }
                }) {
                    Text("CANCEL")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    // This would trigger the scan flow
                }) {
                    Text("UNLOCK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.lemonPrimary)
                        .cornerRadius(12)
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
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isReserved = false
            }
        }
    }
    
    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
