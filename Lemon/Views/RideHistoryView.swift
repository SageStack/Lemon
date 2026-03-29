//
//  RideHistoryView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct RideHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var history: [RideRecord] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("RIDE HISTORY")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().frame(width: 40).opacity(0)
                }
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.lemonPrimary)
                    Spacer()
                } else if history.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No rides yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(history) { ride in
                                RideHistoryRow(ride: ride)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            fetchHistory()
        }
        .onChange(of: authViewModel.currentUser?.id) { old, new in
            if new != nil && history.isEmpty {
                fetchHistory()
            }
        }
    }
    
    private func fetchHistory() {
        guard let userId = authViewModel.currentUser?.id else { 
            // If user is not yet available, don't stop loading, 
            // we'll wait for the onChange to trigger.
            return 
        }
        
        // Prevent multiple simultaneous fetches if already loading with data
        if !history.isEmpty && (isLoading || history.count > 0) {
            // Already have data or loading, but let's allow refresh if history is empty
            if !history.isEmpty { return }
        }
        
        isLoading = true
        
        Task {
            do {
                let records = try await ScooterService.shared.fetchRideHistory(for: userId)
                await MainActor.run {
                    self.history = records
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch history: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}


struct RideHistoryRow: View {
    let ride: RideRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ride.displayDate)
                        .font(.system(size: 14, weight: .bold))
                    
                    if ride.scooterCount > 1 {
                        Text("\(ride.scooterCount) SC")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lemonPrimary)
                            .cornerRadius(4)
                    }
                }
                Text("\(ride.displayDistance) • \(ride.displayDuration)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text(ride.displayCost)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.lemonPrimary)
                .cornerRadius(10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
