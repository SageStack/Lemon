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
    
    init() {
        // Customize Global appearance
        // Moving UI appearance setup here is fine, or can also go to AppDelegate
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }
    
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    authViewModel.handle(url: url)
                }
        }
    }
}
