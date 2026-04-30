//
//  ScooterService.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth
import FirebaseAppCheck

class ScooterService {
    static let shared = ScooterService()
    
    private let db = Database.database(url: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
    private var ref: DatabaseReference?
    private var handle: DatabaseHandle?
    
    // MARK: - Secure Cloud Functions Config
    
    private let functionsUrl = FirebaseManager.shared.functionsBaseUrl
    
    // MARK: - Read Methods (Allowed Direct Read)
    
    private func decodeScooter(from snapshot: DataSnapshot) -> Scooter? {
        guard let value = snapshot.value as? [String: Any] else { return nil }
        
        var data = value
        let scooterId = snapshot.key
        if data["id"] == nil {
            data["id"] = scooterId
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return try self.decoder.decode(Scooter.self, from: jsonData)
        } catch {
            print("Realtime: ❌ Error decoding scooter [\(scooterId)]: \(error.localizedDescription)")
            return nil
        }
    }
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let milliseconds = try container.decode(Double.self)
            return Date(timeIntervalSince1970: milliseconds / 1000.0)
        }
        return d
    }()

    // MARK: - Realtime Geo-Sharding Subscription
    
    /// Subscribes to the given H3 cells for realtime updates using a differential strategy.
    /// - Parameter cells: A list of H3 cell indices
    /// - Parameter onUpdate: Callback with the full list of scooters from these cells
    func subscribeToCells(cells: [String], onUpdate: @escaping ([Scooter]) -> Void) {
        let newCells = Set(cells)
        let currentCells = Set(observers.keys)
        
        // 1. Unsubscribe from cells no longer needed
        let cellsToRemove = currentCells.subtracting(newCells)
        for cell in cellsToRemove {
            if let (ref, handle) = observers[cell] {
                ref.removeObserver(withHandle: handle)
                observers.removeValue(forKey: cell)
                shardCache.removeValue(forKey: cell) // Clean up cache for removed cells
                print("Realtime: 🗑️ Unsubscribed from cell \(cell)")
            }
        }
        
        // 2. Subscribe to new cells
        let cellsToAdd = newCells.subtracting(currentCells)
        if !cellsToAdd.isEmpty {
            print("Realtime: 📡 Subscribing to \(cellsToAdd.count) new H3 shards...")
        }
        
        for cell in cellsToAdd {
            // Priority 0: Load from storage cache for instant UI
            if let cached = StorageService.shared.loadShard(cell: cell) {
                shardCache[cell] = cached
            }
            
            let cellRef = db.child("geo_shards").child(cell)
            let handle = cellRef.observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                self.handleShardUpdate(cell: cell, snapshot: snapshot, onUpdate: onUpdate)
            }
            self.observers[cell] = (cellRef, handle)
        }
        
        // 3. If we removed cells, trigger an immediate UI update with the reduced set
        if !cellsToRemove.isEmpty {
            pushCombinedUpdate(onUpdate: onUpdate)
        }
    }
    
    private var observers: [String: (DatabaseReference, DatabaseHandle)] = [:]
    private var aggregateObservers: [String: (DatabaseReference, DatabaseHandle)] = [:]
    private var shardCache: [String: [Scooter]] = [:] // cell -> [scooters]
    private var discoveryCache: [String: [String]] = [:] // "lat_lng_res" -> [cellIds]
    
    private func handleShardUpdate(cell: String, snapshot: DataSnapshot, onUpdate: @escaping ([Scooter]) -> Void) {
        // If snapshot is null or not a dict, the shard is empty
        guard let value = snapshot.value as? [String: Any] else { 
            shardCache[cell] = []
            pushCombinedUpdate(onUpdate: onUpdate)
            return 
        }
        
        // Parse compact scooters: { id, lat, lng, bat, s }
        var cellScooters: [Scooter] = []
        for (key, data) in value {
            if let dict = data as? [String: Any] {
                let id = dict["id"] as? String ?? key
                let lat = dict["lat"] as? Double ?? 0.0
                let lng = dict["lng"] as? Double ?? 0.0
                let bat = dict["bat"] as? Int ?? 100
                let status = dict["s"] as? String ?? "av" // av, in, mn, rs
                
                let isAvailable = (status == "av")
                let isLocked = (status != "in")
                
                let scooter = Scooter(
                    id: id,
                    name: "Lemon S1", 
                    latitude: lat,
                    longitude: lng,
                    batteryPercentage: bat,
                    isLocked: isLocked,
                    isAvailable: isAvailable,
                    status: status,
                    lastUpdated: Date(),
                    h3Index: cell
                )
                cellScooters.append(scooter)
            }
        }
        
        shardCache[cell] = cellScooters
        StorageService.shared.saveShard(cell: cell, scooters: cellScooters)
        pushCombinedUpdate(onUpdate: onUpdate)
    }
    
    private func pushCombinedUpdate(onUpdate: @escaping ([Scooter]) -> Void) {
        let allScooters = shardCache.values.flatMap { $0 }
        // Debounce or throttle could go here
        onUpdate(allScooters)
    }
    
    func removeAllObservers() {
        for (_, (ref, handle)) in observers {
            ref.removeObserver(withHandle: handle)
        }
        observers.removeAll()
        shardCache.removeAll()
        
        // Also remove aggregate observers
        for (_, (ref, handle)) in aggregateObservers {
            ref.removeObserver(withHandle: handle)
        }
        aggregateObservers.removeAll()
    }

    // MARK: - H3 Bootstrapping
    
    /// Calls the backend to get the H3 cells surrounding the user, to enable subscription.
    /// This avoids needing the H3 library on the client side.
    func getNearbyHostCells(latitude: Double, longitude: Double, resolution: Int = 8) async throws -> [String] {
        // 1. Local Lookup (0ms cost)
        let latQ = Int(latitude * 500) // Approx 200m grid for caching
        let lngQ = Int(longitude * 500)
        let cacheKey = "\(latQ)_\(lngQ)_\(resolution)"
        
        if let cached = discoveryCache[cacheKey] {
            return cached
        }
        
        let data: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "resolution": resolution
        ]
        
        do {
            guard let result = try await callFunction(name: "getNearbyScooters", data: data),
                  let cells = result["cellIds"] as? [String] else {
                return try await loadAvailableShardCellsFallback()
            }

            discoveryCache[cacheKey] = cells
            return cells
        } catch {
            print("[ScooterService] ⚠️ Falling back to direct shard discovery: \(error.localizedDescription)")
            let cells = try await loadAvailableShardCellsFallback()
            discoveryCache[cacheKey] = cells
            return cells
        }
    }

    private func loadAvailableShardCellsFallback() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            db.child("geo_shards").observeSingleEvent(of: .value) { snapshot in
                let cells = snapshot.children.compactMap { child -> String? in
                    (child as? DataSnapshot)?.key
                }
                continuation.resume(returning: cells)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Subscribe to aggregate data (Res 6) for live updates
    func subscribeToAggregates(h3Cells: [String], resolution: Int = 6, onUpdate: @escaping ([ScooterAggregate]) -> Void) {
        print("[ScooterService] 📊 Subscribing to \(h3Cells.count) aggregate cells (Res \(resolution))...")
        
        // Clear existing aggregate observers
        for (_, (ref, handle)) in aggregateObservers {
            ref.removeObserver(withHandle: handle)
        }
        aggregateObservers.removeAll()
        
        var aggregateResults: [String: ScooterAggregate] = [:]
        
        for cell in h3Cells {
            let ref = db.child("geo_aggregates/\(resolution)/\(cell)")
            
            let handle = ref.observe(.value, with: { snapshot in
                guard let data = snapshot.value as? [String: Any],
                      let count = data["count"] as? Int,
                      let lat = data["lat"] as? Double,
                      let lng = data["lng"] as? Double else {
                    // Cell doesn't exist or no data - remove from results
                    aggregateResults.removeValue(forKey: cell)
                    onUpdate(Array(aggregateResults.values))
                    return
                }
                
                let aggregate = ScooterAggregate(id: cell, count: count, latitude: lat, longitude: lng)
                aggregateResults[cell] = aggregate
                
                // Send updated aggregates
                onUpdate(Array(aggregateResults.values))
            })
            
            aggregateObservers[cell] = (ref, handle)
        }
    }
    
    /// Fetches aggregated scooter counts for zoomed-out map views (Res 6 or 4).
    func fetchMapOverview(latitude: Double, longitude: Double, zoomLevel: Double) async throws -> [ScooterAggregate] {
        let data: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "zoomLevel": zoomLevel
        ]
        
        guard let result = try await callFunction(name: "getMapOverview", data: data),
              let aggregatesData = result["aggregates"] as? [[String: Any]] else {
            return []
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: aggregatesData)
        let aggregates = try JSONDecoder().decode([ScooterAggregate].self, from: jsonData)
        return aggregates
    }
    
    // Legacy support
    func unsubscribe() {
        if let handle = handle {
            db.child("scooters").removeObserver(withHandle: handle)
        }
        removeAllObservers()
    }
    
    // MARK: - Secure Write Methods (Cloud Functions)
    
    private func callFunction(name: String, data: [String: Any]) async throws -> [String: Any]? {
        guard let url = URL(string: "\(functionsUrl)/\(name)") else {
            throw NSError(domain: "ScooterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Function URL"])
        }
        
        print("[ScooterService] 🚀 Calling Function: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 10 seconds timeout
        
        // Add ID Token for Auth
        if let user = Auth.auth().currentUser {
            let token = try await user.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // print("[ScooterService] Auth Token present (UID: \(user.uid))") 
        } else {
            print("[ScooterService] ⚠️ WARNING: No current user for callFunction(\(name))")
        }

        // Add App Check Token
        do {
            let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false)
            request.setValue(appCheckToken.token, forHTTPHeaderField: "X-Firebase-AppCheck")
           // print("[ScooterService] App Check Token present")
        } catch {
            print("[ScooterService] ❌ App Check Token Error: \(error.localizedDescription)")
        }
        
        let body: [String: Any] = ["data": data]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        

        guard let httpResponse = response as? HTTPURLResponse else {
             throw NSError(domain: "ScooterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Protocol"])
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
             print("[ScooterService] ❌ Server Status: \(httpResponse.statusCode)")
             // Try to parse error message
             if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let error = json["error"] as? [String: Any],
                let message = error["message"] as? String {
                  throw NSError(domain: "ScooterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
             }
             throw NSError(domain: "ScooterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error: \(httpResponse.statusCode)"])
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            // Firebase Functions returns result in "result" field
            if let result = json?["result"] as? [String: Any] {
                print("[ScooterService] ✅ Successfully extracted 'result' dictionary.")
                return result
            } else {
                print("[ScooterService] ⚠️ Response missing 'result' dictionary.")
                return nil
            }
        } catch {
            print("[ScooterService] ❌ JSON Parsing Error: \(error)")
            throw error
        }
    }
    
    @available(*, deprecated, message: "Use endRide(scooterIds:latitude:longitude:photoUrl:) instead")
    func lockScooters(ids: [String]) async throws {
        // This method is deprecated and should no longer be used.
        // It was previously incorrectly calling endRide without proper parameters.
        throw NSError(domain: "ScooterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "lockScooters is deprecated. Use endRide with parking verification."])
    }
    
    func unlockScooter(id: String, latitude: Double, longitude: Double, useQueue: Bool = true) async throws {
        // Optimistic Unlock: Attempt BLE handshake immediately (Latency < 200ms)
        let bleSuccess = await BLEManager.shared.unlockScooterOptimistically(id: id)
        
        if useQueue {
            TransactionManager.shared.enqueue(type: .unlock, data: [
                "scooterId": id,
                "latitude": latitude,
                "longitude": longitude
            ])
            return // Cloud call will proceed in background via queue
        }

        let data: [String: Any] = [
            "scooterId": id,
            "latitude": latitude,
            "longitude": longitude
        ]
        
        _ = try await callFunction(name: "unlockScooter", data: data)
    }

    func reserveScooter(id: String, userId: String, useQueue: Bool = true) async throws {
        if useQueue {
            TransactionManager.shared.enqueue(type: .reserve, data: ["scooterId": id])
            return
        }

        let data: [String: Any] = [
            "scooterId": id
        ]
        
        _ = try await callFunction(name: "reserveScooter", data: data)
    }
    
    func cancelReservation(id: String) async throws {
        let data: [String: Any] = [
            "scooterId": id
        ]
        
        _ = try await callFunction(name: "cancelReservation", data: data)
    }

    func endRide(scooterIds: [String], latitude: Double, longitude: Double, totalDistanceKm: Double = 0, useQueue: Bool = true) async throws {
        if useQueue {
            TransactionManager.shared.enqueue(type: .endRide, data: [
                "scooterIds": scooterIds,
                "latitude": latitude,
                "longitude": longitude,
                "totalDistance": totalDistanceKm
            ])
            return
        }

        let data: [String: Any] = [
            "scooterIds": scooterIds,
            "latitude": latitude,
            "longitude": longitude,
            "totalDistance": totalDistanceKm
        ]
        
        // Cloud function handles all cost calculation and state updates securely
        _ = try await callFunction(name: "endRide", data: data)
    }
    
    func toggleAlarm(id: String, active: Bool) async throws {
        try await db.child("scooters").child(id).updateChildValues([
            "alarmActive": active,
            "last_updated": ServerValue.timestamp()
        ])
    }

    
    func fetchRideHistory(for userId: String) async throws -> [RideRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            db.child("ride_history").child(userId).observeSingleEvent(of: .value) { snapshot in
                let records = snapshot.children.compactMap { child -> RideRecord? in
                    guard let childSnap = child as? DataSnapshot,
                          var data = childSnap.value as? [String: Any] else { return nil }
                    
                    // Inject missing fields from keys
                    data["id"] = childSnap.key
                    data["userId"] = userId
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .custom { decoder in
                            let container = try decoder.singleValueContainer()
                            let milliseconds = try container.decode(Double.self)
                            return Date(timeIntervalSince1970: milliseconds / 1000.0)
                        }
                        return try decoder.decode(RideRecord.self, from: jsonData)
                    } catch {
                        print("Error decoding ride record: \(error)")
                        return nil
                    }
                }
                // Sort by date descending
                let sortedRecords = records.sorted { $0.date > $1.date }
                continuation.resume(returning: sortedRecords)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
