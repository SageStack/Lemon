//
//  HapticManager.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 05/02/2026.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        print("📳 HapticManager: Impact style \(style.rawValue) triggered")
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        print("📳 HapticManager: Notification type \(type.rawValue) triggered")
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selectionChanged() {
        print("📳 HapticManager: Selection changed triggered")
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
