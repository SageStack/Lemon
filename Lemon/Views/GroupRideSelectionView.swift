//
//  GroupRideSelectionView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct GroupRideSelectionView: View {
    @Binding var isPresented: Bool
    var onScan: () -> Void
    var onReserve: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            // Indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
            
            VStack(spacing: 15) {
                Image(systemName: "person.3.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.lemonPrimary)
                
                Text("GROUP RIDE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                
                Text("Unlock up to 5 scooters on your account. Perfect for friends and family.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 10)
            
            VStack(spacing: 12) {
                Button(action: {
                    isPresented = false
                    onScan()
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("SCAN TO UNLOCK")
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.lemonPrimary)
                    .cornerRadius(15)
                }
                
                Button(action: {
                    isPresented = false
                    onReserve()
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("RESERVE NEARBY")
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(Color.lemonDark)
        .cornerRadius(25, corners: [.topLeft, .topRight])
    }
}
