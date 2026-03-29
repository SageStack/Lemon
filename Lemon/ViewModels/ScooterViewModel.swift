//
//  ScooterViewModel.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import Combine
import CoreLocation

class ScooterViewModel: ObservableObject {
    /// The full list of scooters (unfiltered) for data lookup and active rides
    @Published var scooters: [Scooter] = []
    
    /// Only scooters that are available to be rented (shown on the map)
    @Published var availableScooters: [Scooter] = []
    
    /// Aggregated scooter counts for zoomed-out views
    @Published var aggregates: [ScooterAggregate] = []
    
    /// Toggle between showing individual scooters or aggregates
    @Published var showAggregates: Bool = false
    
    @Published var errorMessage: String?
    @Published var currentResolution: Int = 8
    @Published var currentLatitudeDelta: Double = 0.005
    @Published var estimatedCost: Double = 0.0
    @Published var isSuspiciousMovementDetected: Bool = false
    @Published var isLoading: Bool = false
    
    private var costTimer: Timer?
    private var zoomDebounceTimer: Timer?
    private var securityCancellable: AnyCancellable?
    
    var currentUserId: String? {
        didSet {
            // Re-filter when user changes
            updateScooterList(scooters)
        }
    }
    
    private var lastSubscriptionLocation: CLLocation?
    private var lastSubscriptionResolution: Int?
    
    // Aggregate Cache
    private var lastAggregateLocation: CLLocation?
    private var lastAggregateZoom: Double?
    private var lastAggregateFetchTime: Date?
    private let aggregateCacheDistanceThreshold: CLLocationDistance = 2000 // 2km
    private let aggregateCacheTimeThreshold: TimeInterval = 300 // 5 minutes
    
    private var cancellables = Set<AnyCancellable>()
    
    /// IDs of scooters currently being "represented" on the map to ensure stickiness
    private var currentRepresentativeIds: Set<String> = []
    
    init() {
        print("Realtime: ScooterViewModel initialized")
        setupRealtimeSubscription()
        setupSecurityMonitoring()
    }
    
    deinit {
        print("Realtime: ScooterViewModel DEINITIALIZED ⚠️")
        ScooterService.shared.unsubscribe()
    }
    
    @MainActor
    func loadScooters() async {
        isLoading = true
        errorMessage = nil
        
        print("Realtime: 🚀 Starting H3-based scooter discovery...")
        
        // Initial Fetch
        await refreshData()
        
        isLoading = false
    }
    
    @MainActor
    private func setupRealtimeSubscription() {
        // Listen to Location Updates for Notifications and Periodic Refetch
        LocationManager.shared.$userLocation
             .drop(while: { $0 == nil }) // Wait for actual location
             .removeDuplicates { prev, current in
                guard let p = prev, let c = current else { return false }
                return p.distance(from: c) < 150 // Increased from 100m to 150m for more hysteresis
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self = self, let location = location else { return }
                
                // 1. Evaluate Notifications
                NotificationManager.shared.evaluateScenarios(
                    scooters: self.availableScooters,
                    userLocation: location,
                    lastRideDate: nil
                )
                
            // 2. Fetch new scooters if moved significantly (Bootstrapping H3 Cells)
                Task {
                    await self.refreshData()
                }
            }
            .store(in: &cancellables)
            
        // 3. Listen for Optimistic Updates (Zero-lag UI)
        TransactionManager.shared.optimisticUpdates
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                self?.applyOptimisticUpdate(update)
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func applyOptimisticUpdate(_ update: TransactionManager.OptimisticUpdate) {
        print("Realtime: 🚀 Applying Optimistic Update for \(update.scooterId) - \(update.type)")
        
        // If showing aggregates, force a refresh to likely switch back to details or update counts
        // But if user is zoomed out, they might not see specific scooter anyway.
        // For now, let's just update local state if we have it.
        
        let updateBlock: (inout Scooter) -> Void = { scooter in
            switch update.type {
            case .unlock:
                scooter.isLocked = false
                scooter.isAvailable = false
                scooter.status = "in"
                scooter.currentRideClientId = self.currentUserId
            case .reserve:
                scooter.isAvailable = false
                scooter.status = "rs"
                scooter.reservedBy = self.currentUserId
            case .endRide:
                scooter.isLocked = true
                scooter.isAvailable = true
                scooter.status = "av"
                scooter.currentRideClientId = nil
            }
        }
        
        // Update both lists
        if let index = scooters.firstIndex(where: { $0.id == update.scooterId }) {
            updateBlock(&scooters[index])
        }
        if let index = availableScooters.firstIndex(where: { $0.id == update.scooterId }) {
            updateBlock(&availableScooters[index])
        }
    }

    func startRideTracking(startTime: Date) {
        costTimer?.invalidate()
        costTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.estimatedCost = CostEstimator.estimateCost(startTime: startTime)
        }
        PassiveSecurityService.shared.stopMonitoring()
    }
    
    func stopRideTracking() {
        costTimer?.invalidate()
        costTimer = nil
        estimatedCost = 0.0
        PassiveSecurityService.shared.startMonitoring()
    }
    
    private func setupSecurityMonitoring() {
        securityCancellable = PassiveSecurityService.shared.$isSuspiciousMovementDetected
            .receive(on: RunLoop.main)
            .assign(to: \.isSuspiciousMovementDetected, on: self)
    }

    /// Master method to decide what data to fetch based on Zoom & Location
    @MainActor
    private func refreshData() async {
        guard let location = LocationManager.shared.userLocation else { return }
        
        if currentLatitudeDelta > 0.06 { // Increased threshold slightly for cleaner detail view
            // ZOOMED OUT: AGGREGATES
            print("Realtime: 🦅 Zoomed Out (Delta \(currentLatitudeDelta)). Fetching Aggregates...")
            
            if !showAggregates {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showAggregates = true
                }
            }
            
            // Keep detailed scooters for a bit to allow overlap transition
            // self.availableScooters = [] -> Removed for smoother fade
            
            // Unsubscribe from detailed scooter updates to save bandwidth
            ScooterService.shared.unsubscribe()
            lastSubscriptionLocation = nil // Reset so we resubscribe when zooming back in
            
            // Smart Cache: Check if we need to refresh subscriptions
            let zoomLevel = currentLatitudeDelta > 0.5 ? 9.0 : 12.0
            let resolution = zoomLevel < 10 ? 4 : 6
            
            let shouldRefresh: Bool = {
                guard let lastLoc = lastAggregateLocation,
                      let lastZoom = lastAggregateZoom,
                      let lastFetchTime = lastAggregateFetchTime else {
                    return true // First load
                }
                
                let distanceMoved = location.distance(from: lastLoc)
                let zoomChanged = abs(lastZoom - zoomLevel) > 0.5
                let timeExpired = Date().timeIntervalSince(lastFetchTime) > aggregateCacheTimeThreshold
                
                return distanceMoved > aggregateCacheDistanceThreshold || zoomChanged || timeExpired
            }()
            
            if shouldRefresh {
                do {
                    print("Realtime: 📡 Subscribing to fresh aggregates (threshold crossed)...")
                    
                    // Get H3 cells to subscribe to
                    let cells = try await ScooterService.shared.getNearbyHostCells(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        resolution: resolution
                    )
                    
                    // Subscribe to aggregate updates
                    ScooterService.shared.subscribeToAggregates(h3Cells: cells, resolution: resolution) { [weak self] aggs in
                        DispatchQueue.main.async {
                            self?.aggregates = aggs
                            print("Realtime: 🔄 Aggregates updated: \(aggs.count) cells")
                        }
                    }
                    
                    self.lastAggregateLocation = location
                    self.lastAggregateZoom = zoomLevel
                    self.lastAggregateFetchTime = Date()
                    
                } catch {
                    print("Realtime: ⚠️ Failed to subscribe to aggregates: \(error)")
                }
            } else {
                print("Realtime: 💾 Using cached aggregate subscriptions (\(aggregates.count) items).")
            }
            
        } else {
            // ZOOMED IN: DETAILED SCOOTERS
            if showAggregates && currentLatitudeDelta < 0.04 { // Added hysteresis
                withAnimation(.easeInOut(duration: 0.5)) {
                    showAggregates = false
                    self.aggregates = [] // Clear aggregates
                }
            }
            
            await updateH3Subscription()
        }
    }

    @MainActor
    private func updateH3Subscription() async {
        guard let location = LocationManager.shared.userLocation else { return }
        
        // 1. Calculate Predictive Look-ahead
        var fetchLocation = location.coordinate
        if location.speed > 2.0 {
            let distanceToLookAhead = location.speed * 30.0 
            let bearing = location.course 
            
            let lat1 = location.coordinate.latitude * .pi / 180
            let lon1 = location.coordinate.longitude * .pi / 180
            let brng = bearing * .pi / 180
            let dR = distanceToLookAhead / 6371000.0 
            
            let lat2 = asin(sin(lat1) * cos(dR) + cos(lat1) * sin(dR) * cos(brng))
            let lon2 = lon1 + atan2(sin(brng) * sin(dR) * cos(lat1), cos(dR) - sin(lat1) * sin(lat2))
            
            fetchLocation = CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
        }
        
        // Optimization
        if let lastLoc = lastSubscriptionLocation,
           let lastRes = lastSubscriptionResolution,
           lastLoc.distance(from: location) < 100 && lastRes == currentResolution {
            return
        }
        
        do {
            print("Realtime: 🔄 Requesting Host H3 Cells (Res \(currentResolution)) for predicted location...")
            
            let cells = try await ScooterService.shared.getNearbyHostCells(
                latitude: fetchLocation.latitude,
                longitude: fetchLocation.longitude,
                resolution: 8 // Forced Pin
            )
            
            lastSubscriptionLocation = location
            lastSubscriptionResolution = currentResolution
            
            if !cells.isEmpty {
                print("Realtime: ✅ Received \(cells.count) cells. Subscribing...")
                ScooterService.shared.subscribeToCells(cells: cells) { [weak self] updatedScooters in
                    DispatchQueue.main.async {
                        self?.updateScooterList(updatedScooters)
                    }
                }
            }
        } catch {
            print("Realtime: ⚠️ Failed to update H3 subscription: \(error)")
        }
    }

    @MainActor
    private func updateScooterList(_ allScooters: [Scooter]) {
        self.scooters = allScooters
        
        // If showing aggregates, ignore scooter updates unless we have an active ride
        if showAggregates {
            return
        }

        guard let userLoc = LocationManager.shared.userLocation else {
            self.availableScooters = Array(allScooters.prefix(50))
            return
        }

        // 1. Sort deterministically using ID + Cell to prevent reshuffling on every update
        let sortedScooters = allScooters.sorted { s1, s2 in
            let hash1 = deterministicHash(id: s1.id, cell: s1.h3Index ?? "")
            let hash2 = deterministicHash(id: s2.id, cell: s2.h3Index ?? "")
            if hash1 != hash2 {
                return hash1 < hash2
            }
            return s1.id < s2.id
        }

        // 2. Filter by distance and availability
        // Street Level: < ~120m
        // Mid Level: < ~300m
        let maxDistance: CLLocationDistance = currentLatitudeDelta < 0.01 ? 120 : 300

        let availableCandidates = sortedScooters.filter { scooter in
            // Basic Availability
            let isLocked = scooter.isLocked ?? true
            let isAvailable = scooter.isAvailable ?? true
            let reservedBy = scooter.reservedBy
            let isReservedByOthers = reservedBy != nil && reservedBy != currentUserId
            let isCurrentRide = scooter.currentRideClientId == currentUserId
            
            let statusOk = (isLocked && isAvailable && !isReservedByOthers) || isCurrentRide
            if !statusOk { return false }

            // Bounded Distance Guarantee
            let distance = userLoc.distance(from: CLLocation(latitude: scooter.latitude, longitude: scooter.longitude))
            return distance <= maxDistance
        }

        // 3. Apply Sticky Representative Logic
        // Prioritize scooters that were already visible to prevent replacement flicker
        var finalSelection: [Scooter] = []
        
        // First, keep existing representatives that are still valid candidates
        let stillValidReps = availableCandidates.filter { currentRepresentativeIds.contains($0.id) }
        finalSelection.append(contentsOf: stillValidReps)
        
        // Then, fill remaining slots from candidates not already included
        let remainingQuota = 40 - finalSelection.count
        if remainingQuota > 0 {
            let news = availableCandidates.filter { !currentRepresentativeIds.contains($0.id) }
            finalSelection.append(contentsOf: news.prefix(remainingQuota))
        }
        
        // Keep it sorted by ID for ForEach stability in MapView
        finalSelection.sort { $0.id < $1.id }

        if self.availableScooters != finalSelection {
            self.availableScooters = finalSelection
            self.currentRepresentativeIds = Set(finalSelection.map { $0.id })
            print("Realtime: ✅ Updated Map with \(finalSelection.count) stable markers (Sticky: \(stillValidReps.count))")
            
            NotificationManager.shared.evaluateScenarios(
                scooters: finalSelection,
                userLocation: userLoc,
                lastRideDate: nil
            )
        }
    }

    /// Stable hash to ensure deterministic selection across devices and sessions
    private func deterministicHash(id: String, cell: String) -> Int {
        let combined = id + cell
        return combined.unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1.value)
        }
    }

    @MainActor
    func updateZoomLevel(latitudeDelta: Double) {
        // Store for access in refreshData
        self.currentLatitudeDelta = latitudeDelta
        
        let newRes: Int
        if latitudeDelta < 0.005 {
            newRes = 9
        } else if latitudeDelta < 0.03 {
            newRes = 8
        } else {
            newRes = 7
        }
        
        let needsRefresh = (newRes != currentResolution) || 
                           (latitudeDelta > 0.04 && !showAggregates) || 
                           (latitudeDelta <= 0.04 && showAggregates)

        if needsRefresh {
            zoomDebounceTimer?.invalidate()
            zoomDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    print("Realtime: 🔍 Zoom Settled (Delta \(latitudeDelta)). Updating...")
                    self?.currentResolution = newRes
                    await self?.refreshData()
                }
            }
        }
    }
}
