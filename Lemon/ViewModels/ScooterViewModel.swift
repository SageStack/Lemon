//
//  ScooterViewModel.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine

class ScooterViewModel: ObservableObject {
    /// The full list of scooters (unfiltered) for data lookup and active rides
    @Published var scooters: [Scooter] = []
    
    /// Only scooters that are available to be rented (shown on the map)
    @Published var availableScooters: [Scooter] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        ScooterService.shared.subscribeToScooters { [weak self] updatedScooters in
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
        }
    }
}
