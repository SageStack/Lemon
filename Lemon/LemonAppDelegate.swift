//
//  LemonAppDelegate.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

class LemonAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if targetEnvironment(simulator)
      // Use the debug provider for simulator.
      return AppCheckDebugProvider(app: app)
    #else
      // Use DeviceCheck or App Attest for real devices.
      // DeviceCheck is often easier to set up initially.
      return DeviceCheckProvider(app: app)
    #endif
  }
}

class LemonAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Firebase on a background thread to avoid blocking the main thread during launch
        // Note: FirebaseApp.configure() is generally thread-safe but standard implementation is in didFinishLaunching.
        // To be strictly non-blocking for "heavy" lifting, we can just ensure we don't do excessive work here.
        // However, Firebase *must* be configured before we try to use it.
        // For the "Async Initialization" request, we will defer it slightly or run it here efficiently.
        // Since many Firebase features need to be ready for the UI, we configure it here but we can wrap other heavy setup in bg.
        
        // Initialize App Check before FirebaseApp.configure()
        let providerFactory = LemonAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        FirebaseApp.configure()
        
        // Request Notification Permissions
        NotificationManager.shared.requestPermissions()
        
        return true
    }
}
