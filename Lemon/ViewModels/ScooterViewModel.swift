//
//  ScooterViewModel.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine

class ScooterViewModel: ObservableObject {
    @Published var scooters: [Scooter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
            // Initial fetch
            self.scooters = try await ScooterService.shared.fetchScooters()
            // Setup real-time listener
            setupRealtimeSubscription()
        } catch {
            self.errorMessage = "Unable to fetch scooter data."
            self.scooters = []
        }
        
        isLoading = false
    }
    
    @MainActor
    private func setupRealtimeSubscription() {
        ScooterService.shared.subscribeToScooters { [weak self] updatedScooters in
            DispatchQueue.main.async {
                // Only show scooters that are locked (available for rent)
                self?.scooters = updatedScooters.filter { $0.isLocked == true && $0.isAvailable != false }
                print("Realtime: ✅ Updated UI with \(self?.scooters.count ?? 0) available scooters")
            }
        }
    }
}
