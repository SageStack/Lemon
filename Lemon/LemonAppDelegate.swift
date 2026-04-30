//
//  LemonAppDelegate.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

class LemonAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if DEBUG
      // Use the debug provider for development on both simulator AND physical devices.
      let token = UserDefaults.standard.string(forKey: "FIRAAppCheckDebugToken") ?? "NOT_FOUND"
      print("[AppCheck] Creating AppCheckDebugProvider. Active Token in UserDefaults: \(token)")
      return AppCheckDebugProvider(app: app)
    #else
      #if targetEnvironment(simulator)
        print("[AppCheck] Creating AppCheckDebugProvider (Simulator)")
        return AppCheckDebugProvider(app: app)
      #else
        // Use DeviceCheck or App Attest for production on real devices.
        print("[AppCheck] Creating DeviceCheckProvider (Production/Real Device)")
        return DeviceCheckProvider(app: app)
      #endif
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
        #if DEBUG
        // App Check Debug Provider initialized. 
        // Note: Register the token printed by Firebase (I-GAC004001) in the Firebase Console.
        if let token = ProcessInfo.processInfo.environment["FIRAAppCheckDebugToken"] {
            UserDefaults.standard.set(token, forKey: "FIRAAppCheckDebugToken")
            print("[AppCheck] Debug token loaded from FIRAAppCheckDebugToken environment variable.")
        } else {
            print("[AppCheck] Missing FIRAAppCheckDebugToken environment variable.")
        }
        print("[AppCheck] Debug Provider Factory initialized.")
        #endif

        let providerFactory = LemonAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        FirebaseApp.configure()
        
        // Request Notification Permissions
        NotificationManager.shared.requestPermissions()
        
        return true
    }
}
