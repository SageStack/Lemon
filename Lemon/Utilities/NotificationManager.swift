//
//  NotificationManager.swift
//  Lemon
//
//  Created by Antigravity on 05/02/2026.
//

import Foundation
import CoreLocation
import UserNotifications

enum NotificationRule: String, CaseIterable {
    case proximityEntry
    case commuteAssist
    case lateNightSafe
    case rainStop
    
    var baseRelevance: Double {
        switch self {
        case .proximityEntry: return 0.8
        case .commuteAssist: return 0.95
        case .lateNightSafe: return 0.9
        case .rainStop: return 0.7
        }
    }
    
    var cooldown: TimeInterval {
        switch self {
        case .proximityEntry: return 6 * 3600 // 6 hours
        case .commuteAssist: return 24 * 3600 // 24 hours
        case .lateNightSafe: return 12 * 3600 // 12 hours
        case .rainStop: return 4 * 3600 // 4 hours
        }
    }
    
    var radius: Double {
        switch self {
        case .proximityEntry: return 300
        case .commuteAssist: return 500
        case .lateNightSafe: return 400
        case .rainStop: return 500
        }
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    
    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current
    
    private init() {
        requestPermissions()
    }
    
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notifications: Permission granted ✅")
            } else if let error = error {
                print("Notifications: Permission denied ❌ \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Smart Logic Engine
    
    func evaluateScenarios(scooters: [Scooter], userLocation: CLLocation, lastRideDate: Date?) {
        let nearbyScooters = scooters.filter {
            guard let lat = $0.latitude as Double?, let lon = $0.longitude as Double? else { return false }
            let scooterLoc = CLLocation(latitude: lat, longitude: lon)
            return scooterLoc.distance(from: userLocation) <= 500 // Max check radius
        }
        
        guard let bestScooter = nearbyScooters.sorted(by: {
            let loc1 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            let loc2 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
            return loc1.distance(from: userLocation) < loc2.distance(from: userLocation)
        }).first else { return }
        
        // Evaluate each rule
        for rule in NotificationRule.allCases {
            if checkRule(rule, userLocation: userLocation, scooter: bestScooter, lastRideDate: lastRideDate) {
                // If a rule matches and passes scoring, stop (don't send multiple)
                break
            }
        }
    }
    
    private func checkRule(_ rule: NotificationRule, userLocation: CLLocation, scooter: Scooter, lastRideDate: Date?) -> Bool {
        // 1. Check Proximity
        let scooterLoc = CLLocation(latitude: scooter.latitude, longitude: scooter.longitude)
        let distance = scooterLoc.distance(from: userLocation)
        guard distance <= rule.radius else { return false }
        
        // 2. Check Time/Context Conditions
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let isWeekday = !calendar.isDateInWeekend(now)
        
        switch rule {
        case .commuteAssist:
            let isMorning = (7...9).contains(hour)
            let isEvening = (17...19).contains(hour)
            guard (isMorning || isEvening) && isWeekday else { return false }
        case .lateNightSafe:
            guard !isWeekday && hour >= 23 else { return false }
        case .rainStop:
            return false // Placeholder: Need Weather API
        case .proximityEntry:
            break // Always true if distance is met
        }
        
        // 3. Check Cooldown
        if let lastSent = defaults.value(forKey: "last_sent_\(rule.rawValue)") as? Date {
            if now.timeIntervalSince(lastSent) < rule.cooldown {
                return false
            }
        }
        
        // 4. Calculate Relevance Score
        let score = calculateScore(rule: rule, distance: distance, lastRideDate: lastRideDate)
        
        // 5. Trigger if High Value
        if score >= 0.6 {
            triggerNotification(rule: rule, scooter: scooter, distance: distance)
            return true
        }
        
        return false
    }
    
    private func calculateScore(rule: NotificationRule, distance: Double, lastRideDate: Date?) -> Double {
        // Score = (Base * Proximity * Recency) - Fatigue
        
        let base = rule.baseRelevance
        
        // Proximity Weight: 1.0 at 0m, 0.5 at max radius (linear decay)
        let proximityWeight = max(0.5, 1.0 - (distance / (rule.radius * 2)))
        
        // Recency Decay: Boost if user hasn't ridden in > 3 days
        var recencyMultiplier = 1.0
        if let lastDate = lastRideDate {
            let daysSince = Date().timeIntervalSince(lastDate) / (3600 * 24)
            if daysSince > 3 { recencyMultiplier = 1.2 }
        }
        
        // Fatigue Penalty: Reduce by 0.2 for each notification in last 24h
        let recentCount = getRecentNotificationCount()
        let fatiguePenalty = Double(recentCount) * 0.2
        
        return (base * proximityWeight * recencyMultiplier) - fatiguePenalty
    }
    
    private func triggerNotification(rule: NotificationRule, scooter: Scooter, distance: Double) {
        let identifier = UUID().uuidString
        let title: String
        let body: String
        
        // Variables
        let walkTime = Int(distance / 80) // approx 80m/min walking speed
        let battery = scooter.batteryPercentage ?? 100
        
        switch rule {
        case .proximityEntry:
            title = "A Lemon is Nearby! 🍋"
            body = "Ready to explore? There's a scooter just \(walkTime) min away. Skip the walk!"
        case .commuteAssist:
            title = "Commute Ready? 🛴"
            body = "On your way? A fully charged (\(battery)%) scooter is waiting at your usual spot."
        case .lateNightSafe:
            title = "Get Home Safe 🌙"
            body = "Need a ride? Grab a scooter nearby and get home safely."
        case .rainStop:
            title = "Clear Skies! ☀️"
            body = "The rain has stopped. Perfect time for a ride."
        }
        
        sendImmediateNotification(title: title, body: body, identifier: identifier)
        
        // Update History
        defaults.set(Date(), forKey: "last_sent_\(rule.rawValue)")
        logNotificationSent()
        print("🔔 notification triggered: \(rule.rawValue) | Dist: \(Int(distance))m")
    }
    
    // MARK: - Helpers
    
    func sendImmediateNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notifications: Error sending notification ❌ \(error.localizedDescription)")
            }
        }
    }
    
    private func logNotificationSent() {
        var history = defaults.array(forKey: "notification_history") as? [Date] ?? []
        history.append(Date())
        // Keep only last 48 hours
        history = history.filter { Date().timeIntervalSince($0) < 48 * 3600 }
        defaults.set(history, forKey: "notification_history")
    }
    
    private func getRecentNotificationCount() -> Int {
        let history = defaults.array(forKey: "notification_history") as? [Date] ?? []
        let last24h = history.filter { Date().timeIntervalSince($0) < 24 * 3600 }
        return last24h.count
    }
}
