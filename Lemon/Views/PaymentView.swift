//
//  PaymentView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("PAYMENT & WALLET")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().frame(width: 40).opacity(0)
                }
                .padding()
                
                // Wallet Card
                VStack(spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("LEMON WALLET")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.black)
                            Text("Rs. 1,450.00")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Image(systemName: "lemon.fill") // Using a placeholder for brand identity
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.black)
                    }
                    .padding(30)
                    .background(Color.lemonPrimary)
                    .cornerRadius(25)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            alertMessage = "Top Up functionality coming soon."
                            showAlert = true
                        }) {
                            PaymentActionButton(title: "TOP UP", icon: "plus.circle.fill")
                        }
                        
                        Button(action: {
                            alertMessage = "Promo offers coming soon."
                            showAlert = true
                        }) {
                            PaymentActionButton(title: "PROMO", icon: "tag.fill")
                        }
                    }
                }
                .padding(.horizontal)
                
                // Saved Methods
                VStack(alignment: .leading, spacing: 15) {
                    Text("SAVED METHODS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.lemonPrimary)
                        Text("•••• 4242")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                        Spacer()
                        Text("VISA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                // Promo Code
                VStack(alignment: .leading, spacing: 15) {
                    Text("PROMO CODE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("ENTER CODE", text: .constant(""))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Button(action: {
                            alertMessage = "Invalid promo code."
                            showAlert = true
                        }) {
                            Text("APPLY")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                                .background(Color.lemonPrimary)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .alert("Lemon", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct PaymentActionButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}
