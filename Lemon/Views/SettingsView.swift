//
//  SettingsView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var activeSheet: SettingsDestination?
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    @State private var notificationsEnabled = true
    @State private var locationEnabled = true
    @State private var promoEmailsEnabled = false
    
    enum SettingsDestination: Identifiable {
        case profile, payment, support
        var id: Self { self }
    }
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Text("SETTINGS")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // Account Section
                        SettingsSection(title: "ACCOUNT") {
                            VStack(spacing: 1) {
                                SettingsRow(title: "Edit Profile", icon: "person.fill", showChevron: true) {
                                    activeSheet = .profile
                                }
                                SettingsRow(title: "Payment Methods", icon: "creditcard.fill", showChevron: true) {
                                    activeSheet = .payment
                                }
                                SettingsRow(title: "Change Password", icon: "lock.fill", showChevron: true) {
                                    alertMessage = "Password change functionality is coming soon."
                                    showAlert = true
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                        
                        // Preferences Section
                        SettingsSection(title: "PREFERENCES") {
                            VStack(spacing: 1) {
                                ToggleRow(title: "Push Notifications", icon: "bell.fill", isOn: $notificationsEnabled)
                                ToggleRow(title: "Location Services", icon: "location.fill", isOn: $locationEnabled)
                                ToggleRow(title: "Promotional Emails", icon: "envelope.fill", isOn: $promoEmailsEnabled)
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                        
                        // Support Section
                        SettingsSection(title: "SUPPORT & LEGAL") {
                            VStack(spacing: 1) {
                                SettingsRow(title: "Help Center", icon: "questionmark.circle.fill", showChevron: true) {
                                    activeSheet = .support
                                }
                                SettingsRow(title: "Privacy Policy", icon: "hand.raised.fill", showChevron: true) {
                                    alertMessage = "Privacy Policy is not yet available."
                                    showAlert = true
                                }
                                SettingsRow(title: "Terms of Service", icon: "doc.text.fill", showChevron: true) {
                                    alertMessage = "Terms of Service are not yet available."
                                    showAlert = true
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                        
                        
                        // Logout Button
                        Button(action: {
                            Task {
                                await authViewModel.logout()
                                dismiss()
                            }
                        }) {
                            Text("LOGOUT")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.top, 20)
                        
                        // Version Info
                        Text("Version 1.0.0 (Build 124)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(item: $activeSheet) { item in
            switch item {
            case .profile:
                ProfileView()
            case .payment:
                PaymentView()
            case .support:
                SupportView()
            }
        }
        .alert("Coming Soon", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.leading, 5)
            
            content
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    var showChevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.lemonPrimary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding()
            .background(Color.white.opacity(0.001)) // For tap target
        }
        .buttonStyle(PlainButtonStyle())
        
        if showChevron {
            Divider().background(Color.white.opacity(0.05))
                .padding(.leading, 54)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.lemonPrimary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .lemonPrimary))
                .labelsHidden()
        }
        .padding()
        
        Divider().background(Color.white.opacity(0.05))
            .padding(.leading, 54)
    }
}
