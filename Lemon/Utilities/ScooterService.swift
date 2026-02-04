//
//  ScooterService.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import Foundation
import FirebaseDatabase

class ScooterService {
    static let shared = ScooterService()
    
    private let db = Database.database().reference()
    private var ref: DatabaseReference?
    private var handle: DatabaseHandle?
    
    func fetchScooters() async throws -> [Scooter] {
        return try await withCheckedThrowingContinuation { continuation in
            db.child("scooters").observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                let scooters = snapshot.children.compactMap { child -> Scooter? in
                    guard let childSnap = child as? DataSnapshot,
                          let value = childSnap.value as? [String: Any] else { return nil }
                    
                    var data = value
                    if data["id"] == nil {
                        data["id"] = childSnap.key
                    }
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        return try self.decoder.decode(Scooter.self, from: jsonData)
                    } catch {
                        print("Decoding error: \(error)")
                        return nil
                    }
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
                guard let childSnap = child as? DataSnapshot,
                      let value = childSnap.value as? [String: Any] else { return nil }
                
                var data = value
                if data["id"] == nil {
                    data["id"] = childSnap.key
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    return try self.decoder.decode(Scooter.self, from: jsonData)
                } catch {
                    return nil
                }
            }
            onChange(scooters)
        }
    }
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // RTDB date handling: assume milliseconds since 1970
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
    
    // MARK: - Remote Commands
    
    func unlockScooter(id: String) async throws {
        try await db.child("scooters").child(id).updateChildValues([
            "is_locked": false,
            "last_updated": ServerValue.timestamp()
        ])
    }
    
    func lockScooter(id: String) async throws {
        try await db.child("scooters").child(id).updateChildValues([
            "is_locked": true,
            "last_updated": ServerValue.timestamp()
        ])
    }
    
    func unlockScooters(ids: [String]) async throws {
        var updates: [String: Any] = [:]
        let timestamp = ServerValue.timestamp()
        for id in ids {
            updates["scooters/\(id)/is_locked"] = false
            updates["scooters/\(id)/last_updated"] = timestamp
        }
        try await db.updateChildValues(updates)
    }
    
    func lockScooters(ids: [String]) async throws {
        var updates: [String: Any] = [:]
        let timestamp = ServerValue.timestamp()
        for id in ids {
            updates["scooters/\(id)/is_locked"] = true
            updates["scooters/\(id)/last_updated"] = timestamp
        }
        try await db.updateChildValues(updates)
    }
}
