//
//  GroupRideView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct GroupRideView: View {
    @Environment(\.dismiss) var dismiss
    @State private var groupSize = 1
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                VStack(spacing: 15) {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.lemonPrimary)
                    
                    Text("GROUP RIDE")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                    
                    Text("Unlock multiple scooters with a single account. Perfect for friends and family.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                VStack(spacing: 20) {
                    Text("ADDITIONAL RIDERS")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.lemonPrimary)
                    
                    HStack(spacing: 30) {
                        Button(action: { if groupSize > 1 { groupSize -= 1 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        
                        Text("\(groupSize)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                        
                        Button(action: { if groupSize < 5 { groupSize += 1 } }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.lemonPrimary)
                        }
                    }
                }
                .padding(30)
                .background(Color.white.opacity(0.05))
                .cornerRadius(25)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("START GROUP RIDE")
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
    }
}
