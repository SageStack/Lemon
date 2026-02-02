//
//  ScooterService.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import Foundation
import FirebaseFirestore

class ScooterService {
    static let shared = ScooterService()
    
    private let db = FirebaseManager.shared.db
    private var listener: ListenerRegistration?
    
    func fetchScooters() async throws -> [Scooter] {
        let snapshot = try await db.collection("scooters").getDocuments()
        let scooters = try snapshot.documents.compactMap { document -> Scooter? in
            // Map Firestore data to Scooter model
            // Firestore data is typically [String: Any]
            // We can use Codable support if we configure it correctly
            var data = document.data()
            // Ensure ID is set correctly (Firestore doc ID or field)
            if data["id"] == nil {
                data["id"] = document.documentID
            }
            
            // Manual decoding helper or json-based decoding
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // Or however Firestore stores it
            return try decoder.decode(Scooter.self, from: jsonData)
        }
        
        return scooters
    }
    
    func subscribeToScooters(onChange: @escaping ([Scooter]) -> Void) {
        listener = db.collection("scooters").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Realtime: ❌ Error fetching snapshots: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let scooters = documents.compactMap { document -> Scooter? in
                var data = document.data()
                if data["id"] == nil {
                    data["id"] = document.documentID
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let decoder = JSONDecoder()
                    // Customize decoder for Firestore timestamps if needed
                    return try decoder.decode(Scooter.self, from: jsonData)
                } catch {
                    print("Realtime: ❌ Decoding error: \(error)")
                    return nil
                }
            }
            
            print("Realtime: ✅ Snapshot received: \(scooters.count) scooters")
            onChange(scooters)
        }
    }
    
    func unsubscribe() {
        listener?.remove()
    }
}
