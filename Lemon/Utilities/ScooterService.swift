//
//  ScooterService.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

class ScooterService {
    static let shared = ScooterService()
    
    private let db = Database.database().reference()
    private var ref: DatabaseReference?
    private var handle: DatabaseHandle?
    
    // MARK: - Secure Cloud Functions Config
    
    // MARK: - Secure Cloud Functions Config
    
    private let functionsUrl = FirebaseManager.shared.functionsBaseUrl
    
    // MARK: - Read Methods (Allowed Direct Read)
    
    func fetchScooters() async throws -> [Scooter] {
        return try await withCheckedThrowingContinuation { continuation in
            db.child("scooters").observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                let scooters = snapshot.children.compactMap { child -> Scooter? in
                    guard let childSnap = child as? DataSnapshot else { return nil }
                    return self.decodeScooter(from: childSnap)
                }
                continuation.resume(returning: scooters)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    func subscribeToScooters(onChange: @escaping ([Scooter]) -> Void) {
        handle = db.child("scooters").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            let scooters = snapshot.children.compactMap { child -> Scooter? in
                guard let childSnap = child as? DataSnapshot else { return nil }
                return self.decodeScooter(from: childSnap)
            }
            onChange(scooters)
        }
    }

    /// Optimized subscription based on geohash prefix (Spatial Filtering)
    func subscribeToScootersInRegion(geohashPrefix: String, onChange: @escaping ([Scooter]) -> Void) {
        // Unsubscribe from previous if needed, though usually handled by viewmodel
        unsubscribe() 
        
        ref = db.child("scooters")
        handle = ref?.queryOrdered(byChild: "geohash")
            .queryStarting(at: geohashPrefix)
            .queryEnding(at: geohashPrefix + "\u{f8ff}")
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                let scooters = snapshot.children.compactMap { child -> Scooter? in
                    guard let childSnap = child as? DataSnapshot else { return nil }
                    return self.decodeScooter(from: childSnap)
                }
                onChange(scooters)
            }
    }

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
    
    func unsubscribe() {
        if let handle = handle {
            db.child("scooters").removeObserver(withHandle: handle)
        }
    }
    
    // MARK: - Secure Write Methods (Cloud Functions)
    
    private func callFunction(name: String, data: [String: Any]) async throws -> [String: Any]? {
        guard let url = URL(string: "\(functionsUrl)/\(name)") else {
            throw NSError(domain: "ScooterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Function URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add ID Token for Auth
        if let user = Auth.auth().currentUser {
            let token = try await user.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["data": data]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw NSError(domain: "ScooterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Protocol"])
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
             // Try to parse error message
             if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let error = json["error"] as? [String: Any],
                let message = error["message"] as? String {
                 throw NSError(domain: "ScooterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
             }
             throw NSError(domain: "ScooterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error: \(httpResponse.statusCode)"])
        }
        
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        // Firebase Functions returns result in "result" field
        return json?["result"] as? [String: Any]
    }
    
    func unlockScooter(id: String, latitude: Double, longitude: Double) async throws {
        _ = try await callFunction(name: "unlockScooter", data: ["scooterId": id, "latitude": latitude, "longitude": longitude])
    }

    
    func reserveScooter(id: String, userId: String) async throws {
        _ = try await callFunction(name: "reserveScooter", data: ["scooterId": id])
    }
    
    func cancelReservation(id: String) async throws {
        _ = try await callFunction(name: "cancelReservation", data: ["scooterId": id])
    }
    
    func endRide(scooterIds: [String], latitude: Double, longitude: Double, photoUrl: String) async throws {
        _ = try await callFunction(name: "endRide", data: [
            "scooterIds": scooterIds,
            "latitude": latitude,
            "longitude": longitude,
            "photoUrl": photoUrl
        ])
    }


    // Deprecated: Locking is handled by endRide
    func lockScooters(ids: [String]) async throws {
        try await endRide(scooterIds: ids, totalDistance: 0.0)
    }
    
    func toggleAlarm(id: String, active: Bool) async throws {
        _ = try await callFunction(name: "toggleAlarm", data: ["scooterId": id, "active": active])
    }

    
    func fetchRideHistory(for userId: String) async throws -> [RideRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            db.child("ride_history").child(userId).observeSingleEvent(of: .value) { snapshot in
                let records = snapshot.children.compactMap { child -> RideRecord? in
                    guard let childSnap = child as? DataSnapshot,
                          let value = childSnap.value as? [String: Any] else { return nil }
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: value)
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
