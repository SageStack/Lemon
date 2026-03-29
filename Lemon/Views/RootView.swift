//
//  RootView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainDashboardView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authViewModel.isAuthenticated)
    }
}
