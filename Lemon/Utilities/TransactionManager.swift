//
//  TransactionManager.swift
//  Lemon
//
//  Created by antigravity on 11/02/2026.
//

import Foundation
import Network
import Combine

/// Manages a persistent queue of critical transactions to ensure reliability in poor network conditions.
class TransactionManager: ObservableObject {
    static let shared = TransactionManager()
    
    @Published private(set) var pendingTransactions: [PendingTransaction] = []
    
    /// Broadcasts optimistic state updates for the UI to reflect changes instantly.
    let optimisticUpdates = PassthroughSubject<OptimisticUpdate, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "TransactionManager")
    private var isProcessing = false
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.pendingTransactions = StorageService.shared.loadTransactions()
        setupNetworkMonitoring()
        
        // Auto-process on launch if network is up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.processQueue()
        }
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("TransactionManager: 🌐 Network restored. Processing queue...")
                self?.processQueue()
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Adds a transaction to the queue and persists it.
    func enqueue(type: PendingTransaction.TransactionType, data: [String: Any]) {
        let anyCodableData = data.mapValues { AnyCodable($0) }
        let transaction = PendingTransaction(
            id: UUID().uuidString,
            type: type,
            data: anyCodableData,
            timestamp: Date(),
            retryCount: 0
        )
        
        // Broadcast optimistic update for instant UI feedback
        if let scooterId = data["scooterId"] as? String {
            optimisticUpdates.send(OptimisticUpdate(scooterId: scooterId, type: type))
        }
        
        DispatchQueue.main.async {
            self.pendingTransactions.append(transaction)
            StorageService.shared.saveTransactions(self.pendingTransactions)
            self.processQueue()
        }
    }
    
    struct OptimisticUpdate {
        let scooterId: String
        let type: PendingTransaction.TransactionType
    }
    
    /// Attempts to process all pending transactions.
    func processQueue() {
        guard !isProcessing && !pendingTransactions.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            let transactions = pendingTransactions
            for transaction in transactions {
                do {
                    try await execute(transaction)
                    // Success: Remove from queue
                    removeTransaction(id: transaction.id)
                } catch {
                    print("TransactionManager: ❌ Failed to process \(transaction.type) [\(transaction.id)]: \(error)")
                    incrementRetry(id: transaction.id)
                }
            }
            isProcessing = false
        }
    }
    
    private func execute(_ transaction: PendingTransaction) async throws {
        let rawData = transaction.data.mapValues { $0.value }
        
        switch transaction.type {
        case .unlock:
            guard let id = rawData["scooterId"] as? String,
                  let lat = rawData["latitude"] as? Double,
                  let lng = rawData["longitude"] as? Double else { return }
            try await ScooterService.shared.unlockScooter(id: id, latitude: lat, longitude: lng, useQueue: false)
            
        case .endRide:
            guard let ids = rawData["scooterIds"] as? [String],
                  let lat = rawData["latitude"] as? Double,
                  let lng = rawData["longitude"] as? Double,
                  let dist = rawData["totalDistance"] as? Double else { return }
            try await ScooterService.shared.endRide(scooterIds: ids, latitude: lat, longitude: lng, totalDistanceKm: dist, useQueue: false)
            
        case .reserve:
            guard let id = rawData["scooterId"] as? String else { return }
            try await ScooterService.shared.reserveScooter(id: id, userId: "current", useQueue: false)
        }
    }
    
    private func removeTransaction(id: String) {
        DispatchQueue.main.async {
            self.pendingTransactions.removeAll { $0.id == id }
            StorageService.shared.saveTransactions(self.pendingTransactions)
        }
    }
    
    private func incrementRetry(id: String) {
        DispatchQueue.main.async {
            if let index = self.pendingTransactions.firstIndex(where: { $0.id == id }) {
                self.pendingTransactions[index].retryCount += 1
                // Max retries check could go here
                StorageService.shared.saveTransactions(self.pendingTransactions)
            }
        }
    }
}
