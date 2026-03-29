//
//  GroupRideSelectionView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct GroupRideSelectionView: View {
    @Binding var isPresented: Bool
    var onScan: () -> Void
    var onReserve: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isButtonAnimating = false
    
    var body: some View {
        VStack(spacing: 25) {
            // Indicator
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
            
            VStack(spacing: 15) {
                Image(systemName: "person.3.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.lemonPrimary)
                    .scaleEffect(isButtonAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isButtonAnimating)
                
                Text("GROUP RIDE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text("Unlock up to 5 scooters on your account. Perfect for friends and family.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 10)
            
            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isPresented = false
                    }
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
                    .scaleEffect(isButtonAnimating ? 1.02 : 1.0)
                }
                .onAppear { isButtonAnimating = true }
                
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isPresented = false
                    }
                    onReserve()
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("RESERVE NEARBY")
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.lemonGlassBackground)
                    .cornerRadius(15)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.lemonDark)
        .cornerRadius(30, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: -10)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}
