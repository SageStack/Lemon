//
//  DashboardViewModel.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 10/02/2026.
//

import SwiftUI
import Combine

enum DashboardState {
    case normal
    case groupSelection
    case activeRide
    case reservation
}

class DashboardViewModel: ObservableObject {
    // Navigation & UI State
    @Published var isShowingSideMenu = false
    @Published var selectedMenuItem: MenuItem?
    @Published var isScanning = false
    @Published var isShowingParkingVerification = false
    @Published var showTripSummary = false
    
    // Ride State
    @Published var isActiveRide = false
    @Published var isReserved = false
    @Published var isGroupSelectionMode = false
    
    // Overlays
    @Published var isShowingGroupRideSelection = false
    
    // Data
    @Published var activeScooterIds: [String] = []
    @Published var lastTripData: TripData?
    
    var currentState: DashboardState {
        if isGroupSelectionMode { return .groupSelection }
        if isActiveRide { return .activeRide }
        if isReserved { return .reservation }
        return .normal
    }
    
    func resetGroupSelection() {
        isGroupSelectionMode = false
    }
    
    func toggleSideMenu() {
        withAnimation(.spring()) {
            isShowingSideMenu.toggle()
        }
    }
    
    func showGroupRideSelection() {
        withAnimation(.spring()) {
            isShowingGroupRideSelection = true
        }
    }
    
    func dismissGroupRideSelection() {
        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingGroupRideSelection = false
        }
    }
}
