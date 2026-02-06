//
//  ScooterViewModel.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine
import CoreLocation

class ScooterViewModel: ObservableObject {
    /// The full list of scooters (unfiltered) for data lookup and active rides
    @Published var scooters: [Scooter] = []
    
    /// Only scooters that are available to be rented (shown on the map)
    @Published var availableScooters: [Scooter] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentGeohashPrefix: String?
    
    var currentUserId: String? {
        didSet {
            // Re-filter when user changes
            updateScooterList(scooters)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("Realtime: ScooterViewModel initialized")
    }
    
    deinit {
        print("Realtime: ScooterViewModel DEINITIALIZED ⚠️")
        ScooterService.shared.unsubscribe()
    }
    
    @MainActor
    func loadScooters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await ScooterService.shared.fetchScooters()
            updateScooterList(fetched)
            setupRealtimeSubscription()
        } catch {
            self.errorMessage = "Unable to fetch scooter data."
            self.scooters = []
            self.availableScooters = []
        }
        
        isLoading = false
    }
    
    @MainActor
    private func setupRealtimeSubscription() {
        // Initial subscription with current location if available
        updateSubscriptionRegion()
        
        // Listen to Location Updates for Notifications and Subscription Updates
        LocationManager.shared.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self = self, let location = location else { return }
                
                // 1. Evaluate Notifications
                NotificationManager.shared.evaluateScenarios(
                    scooters: self.availableScooters,
                    userLocation: location,
                    lastRideDate: nil
                )
                
                // 2. Update Subscription if moved to a new geohash prefix
                let newPrefix = GeohashHelper.encode(latitude: location.coordinate.latitude, 
                                                    longitude: location.coordinate.longitude, 
                                                    precision: 4) // ~20km x 20km region for scalability
                if newPrefix != self.currentGeohashPrefix {
                    self.currentGeohashPrefix = newPrefix
                    self.updateSubscriptionRegion()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func updateSubscriptionRegion() {
        guard let prefix = currentGeohashPrefix else {
            // Fallback to global if no location yet, or wait
            return
        }
        
        print("Realtime: Updating spatial subscription to region [\(prefix)]")
        ScooterService.shared.subscribeToScootersInRegion(geohashPrefix: prefix) { [weak self] updatedScooters in
            self?.updateScooterList(updatedScooters)
        }
    }

    @MainActor
    private func updateScooterList(_ allScooters: [Scooter]) {
        // 1. Maintain the full list for context
        self.scooters = allScooters
        
        // 2. Filter for map availability:
        // - Must be Locked
        // - Must be Available
        // - Must NOT be reserved OR be reserved by CURRENT user
        let filtered = allScooters.filter { scooter in
            let isLocked = scooter.isLocked ?? true
            let isAvailable = scooter.isAvailable ?? true
            let reservedBy = scooter.reservedBy
            
            let isReservedByOthers = reservedBy != nil && reservedBy != currentUserId
            
            return isLocked && isAvailable && !isReservedByOthers
        }
        
        if self.availableScooters != filtered {
            self.availableScooters = filtered
            print("Realtime: ✅ Updated Map with \(filtered.count) scooters (Total in DB: \(allScooters.count))")
            
            // Trigger Notification Check on Data Update
            if let userLoc = LocationManager.shared.userLocation {
                NotificationManager.shared.evaluateScenarios(
                    scooters: filtered,
                    userLocation: userLoc,
                    lastRideDate: nil
                )
            }
        }
    }
}
