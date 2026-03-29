//
//  ProfileView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color.lemonGlassBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("PROFILE")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().frame(width: 40).opacity(0) // Spacer for centering
                }
                .padding()
                
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.lemonPrimary)
                
                VStack(spacing: 15) {
                    InfoRow(label: "NAME", value: authViewModel.currentUser?.name ?? "Shaluka")
                    InfoRow(label: "EMAIL", value: authViewModel.currentUser?.email ?? "shaluka@example.com")
                    InfoRow(label: "PHONE", value: "+94 77 123 4567")
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .medium))
        }
        .padding()
        .background(Color.lemonCardBackground)
        .cornerRadius(12)
    }
}
