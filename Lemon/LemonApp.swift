//
//  LemonApp.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import FirebaseCore

@main
struct LemonApp: App {
    @UIApplicationDelegateAdaptor(LemonAppDelegate.self) var delegate
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Global appearance customization can go here
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(themeManager.selection.colorScheme)
                .environmentObject(themeManager)
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    authViewModel.handle(url: url)
                }
        }
    }
}
