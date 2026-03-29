//
//  StorageService.swift
//  Lemon
//
//  Created by antigravity on 11/02/2026.
//

import Foundation

/// A high-performance storage service for caching Geo-Shards and pending transactions.
class StorageService {
    static let shared = StorageService()
    private let fileManager = FileManager.default
    
    private var cacheURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("geo_shards")
    }
    
    private init() {
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Shard Caching
    
    func saveShard(cell: String, scooters: [Scooter]) {
        let fileURL = cacheURL.appendingPathComponent("\(cell).json")
        do {
            let data = try JSONEncoder().encode(scooters)
            try data.write(to: fileURL)
        } catch {
            print("Storage: ❌ Error saving shard \(cell): \(error)")
        }
    }
    
    func loadShard(cell: String) -> [Scooter]? {
        let fileURL = cacheURL.appendingPathComponent("\(cell).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Scooter].self, from: data)
        } catch {
            print("Storage: ❌ Error loading shard \(cell): \(error)")
            return nil
        }
    }
    
    // MARK: - Transaction Persistence
    
    private var transactionsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("pending_transactions.json")
    }
    
    func saveTransactions(_ transactions: [PendingTransaction]) {
        do {
            let data = try JSONEncoder().encode(transactions)
            try data.write(to: transactionsURL)
        } catch {
            print("Storage: ❌ Error saving transactions: \(error)")
        }
    }
    
    func loadTransactions() -> [PendingTransaction] {
        guard fileManager.fileExists(atPath: transactionsURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: transactionsURL)
            return try JSONDecoder().decode([PendingTransaction].self, from: data)
        } catch {
            print("Storage: ❌ Error loading transactions: \(error)")
            return []
        }
    }
}

struct PendingTransaction: Codable, Identifiable {
    let id: String
    let type: TransactionType
    let data: [String: AnyCodable]
    let timestamp: Date
    var retryCount: Int
    
    enum TransactionType: String, Codable {
        case unlock
        case endRide
        case reserve
    }
}

/// A type-erased wrapper for JSON-serializable types to support [String: Any] in Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnyCodable].self) { value = x.mapValues { $0.value } }
        else if let x = try? container.decode([AnyCodable].self) { value = x.map { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value is not dynamic-friendly") }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? String { try container.encode(x) }
        else if let x = value as? Double { try container.encode(x) }
        else if let x = value as? Int { try container.encode(Double(x)) }
        else if let x = value as? Bool { try container.encode(x) }
        else if let x = value as? [String: Any] { try container.encode(x.mapValues { AnyCodable($0) }) }
        else if let x = value as? [Any] { try container.encode(x.map { AnyCodable($0) }) }
    }
}
