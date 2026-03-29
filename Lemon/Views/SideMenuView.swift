//
//  SideMenuView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isShowing: Bool
    @Binding var selectedMenuItem: MenuItem?
    
    var body: some View {
        ZStack {
            // Semi-transparent background for closing
            if isShowing {
                Color.primary.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isShowing = false
                        }
                    }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    // Profile Header
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.lemonPrimary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(authViewModel.currentUser?.name ?? "User")
                                .font(.system(size: 20, weight: .bold))
                            
                            Text("Premium Member")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.lemonPrimary)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    // Menu Items
                    VStack(alignment: .leading, spacing: 25) {
                        MenuRow(item: .profile, isSelected: selectedMenuItem == .profile) {
                            selectItem(.profile)
                        }
                        MenuRow(item: .history, isSelected: selectedMenuItem == .history) {
                            selectItem(.history)
                        }
                        MenuRow(item: .payment, isSelected: selectedMenuItem == .payment) {
                            selectItem(.payment)
                        }
                        MenuRow(item: .settings, isSelected: selectedMenuItem == .settings) {
                            selectItem(.settings)
                        }
                        MenuRow(item: .safety, isSelected: selectedMenuItem == .safety) {
                            selectItem(.safety)
                        }
                        MenuRow(item: .support, isSelected: selectedMenuItem == .support) {
                            selectItem(.support)
                        }
                    }
                    
                    Spacer()
                    
                    // Logout
                    Button(action: {
                        Task {
                            await authViewModel.logout()
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("LOGOUT")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 30)
                .frame(width: 280)
                .background(Color.lemonBackground)
                .offset(x: isShowing ? 0 : -280)
                
                Spacer()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isShowing)
    }
    
    private func selectItem(_ item: MenuItem) {
        selectedMenuItem = item
        isShowing = false
    }
}

enum MenuItem: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case profile = "PROFILE"
    case history = "RIDE HISTORY"
    case payment = "PAYMENT"
    case safety = "SAFETY CENTER"
    case settings = "SETTINGS"
    case support = "SUPPORT"
    
    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .history: return "clock.fill"
        case .payment: return "creditcard.fill"
        case .safety: return "shield.lefthalf.filled"
        case .settings: return "gearshape.fill"
        case .support: return "questionmark.circle.fill"
        }
    }
}

struct MenuRow: View {
    let item: MenuItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: item.icon)
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.clear : Color.lemonPrimary.opacity(0.8))
                    .clipShape(Circle())
                
                Text(item.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .black : .primary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.lemonPrimary : Color.clear)
            .cornerRadius(12)
        }
    }
}
