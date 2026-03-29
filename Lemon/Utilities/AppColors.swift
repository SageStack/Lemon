//
//  AppColors.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import UIKit
import Foundation
import Combine

extension Color {
    // The signature "Neon Lemon" color - Adaptive
    static var lemonPrimary: Color {
        Color(.displayP3, red: 0.9535, green: 0.9818, blue: 0.4271, opacity: 1.0)
    }
    
    // A glass-like background for overlays and containers
    static var lemonGlassBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.1) // Subtle white overlay on dark
                : UIColor.black.withAlphaComponent(0.05) // Subtle dark overlay on light
        })
    }
    
    // Specific background for cards to ensure they pop against the base background
    static var lemonCardBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.5) // Semi-transparent dark
                : UIColor.secondarySystemGroupedBackground // Solid white/light gray in light mode
        })
    }
    
    // Semantic separator
    static var lemonSeparator: Color {
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.1)
                : UIColor.black.withAlphaComponent(0.05)
        })
    }
    
    // Base Backgrounds (kept for backward compatibility or updated if needed)
    static let lemonDark = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            : .systemBackground
    })
    
    static let lemonBackground = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
            : .systemGroupedBackground
    })
    
    static let lemonSurface = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
            : .secondarySystemGroupedBackground
    })
    
    // Text colors
    static let lemonSecondaryText = Color.secondary
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selection: AppTheme {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: "selectedTheme")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.selection = theme
        } else {
            self.selection = .system
        }
    }
}
