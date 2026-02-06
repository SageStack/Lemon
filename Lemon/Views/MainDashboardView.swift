//
//  MainDashboardView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var scooterViewModel = ScooterViewModel()
    @State private var selectedScooter: Scooter?
    @State private var isShowingSideMenu = false
    @State private var selectedMenuItem: MenuItem?
    @State private var isScanning = false
    @State private var isActiveRide = false
    @State private var activeScooterIds: [String] = []
    @State private var reservedScooter: Scooter?
    @State private var isReserved = false
    @State private var isShowingParkingVerification = false
    @State private var showTripSummary = false
    @State private var lastTripData: (duration: Int, cost: Double, count: Int, distance: Double)?
    @State private var isShowingGroupRideSelection = false
    @State private var isGroupSelectionMode = false
    @State private var selectedGroupScooters: Set<Scooter> = []
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                // Background Map
                MapView(
                    selectedScooter: $selectedScooter,
                    isGroupSelectionMode: $isGroupSelectionMode,
                    selectedGroupScooters: $selectedGroupScooters,
                    scooters: scooterViewModel.availableScooters
                )
                    .ignoresSafeArea()
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: isActiveRide ? 200 : 150)
                    }
                
                // UI Overlays
                VStack {
                    // Header
                    HStack {
                        HeaderButton(icon: "line.3.horizontal") {
                            withAnimation(.spring()) {
                                isShowingSideMenu.toggle()
                            }
                        }
                        Spacer()
                        Text("LEMON")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .italic()
                            .tracking(3)
                        Spacer()
                        HeaderButton(icon: "person.fill") {
                            selectedMenuItem = .profile
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom Control Panel
                    VStack(spacing: 20) {
                        if isGroupSelectionMode {
                            VStack(spacing: 16) {
                                Text("Select up to 5 scooters")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(selectedGroupScooters.count)/5 SELECTED")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.lemonPrimary)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        isGroupSelectionMode = false
                                        selectedGroupScooters.removeAll()
                                    }) {
                                        Text("CANCEL")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        // Proceed with group reservation
                                        isGroupSelectionMode = false
                                        isReserved = true // Mock reservation
                                        // In real app, we'd reserve all selected scooters
                                    }) {
                                        Text("CONFIRM (\(selectedGroupScooters.count))")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(selectedGroupScooters.isEmpty ? Color.gray : Color.lemonPrimary)
                                            .cornerRadius(12)
                                    }
                                    .disabled(selectedGroupScooters.isEmpty)
                                }
                            }
                            .padding(.horizontal, 24)
                        } else if isActiveRide {
                            ActiveRideView(isActive: $isActiveRide, scooterIds: activeScooterIds, allScooters: scooterViewModel.scooters)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if isReserved, let scooter = reservedScooter {
                            ReservationView(scooter: scooter, isReserved: $isReserved)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            VStack(spacing: 16) {
                                if let scooter = selectedScooter {
                                    ScooterCard(scooter: scooter)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        isShowingGroupRideSelection = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.3.fill")
                                            Text("GROUP")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 120, height: 60)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(15)
                                    }
                                    
                                    ActionButton(title: "SCAN TO UNLOCK", icon: "qrcode.viewfinder") {
                                        isScanning = true
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 25)
                    .padding(.bottom, 30)
                    .background(
                        ZStack {
                            Color.lemonBackground
                            LinearGradient(
                                colors: [.clear, .lemonBackground.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .cornerRadius(35, corners: [.topLeft, .topRight])
                        .ignoresSafeArea()
                    )
                    .overlay(
                        VStack {
                            Divider().background(Color.white.opacity(0.05))
                            Spacer()
                        }
                    )
                }
            }
            .blur(radius: isShowingSideMenu || isShowingGroupRideSelection ? 10 : 0)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReserveScooter"))) { notification in
                if let scooter = notification.object as? Scooter, let userId = authViewModel.currentUser?.id {
                    Task {
                        try? await ScooterService.shared.reserveScooter(id: scooter.id, userId: userId)
                        await MainActor.run {
                            withAnimation {
                                reservedScooter = scooter
                                isReserved = true
                                selectedScooter = nil // Hide card
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnlockScooter"))) { _ in
                isScanning = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestAddScooter"))) { _ in
                isScanning = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestEndRide"))) { notification in
                if let data = notification.object as? (Int, Double, Int, Double) {
                    lastTripData = (data.0, data.1, data.2, data.3)
                }
                isShowingParkingVerification = true
            }
            
            // Side Menu
            SideMenuView(isShowing: $isShowingSideMenu, selectedMenuItem: $selectedMenuItem)
        }
        .background(Color.lemonBackground)
        .sheet(isPresented: $showTripSummary) {
            if let data = lastTripData {
                TripSummaryView(duration: data.duration, cost: data.cost, scooterCount: data.count, distance: data.distance) {
                    showTripSummary = false
                    lastTripData = nil
                }
            }
        }
        .sheet(item: $selectedMenuItem) { item in
            switch item {
            case .profile:
                ProfileView()
            case .history:
                RideHistoryView()
            case .payment:
                PaymentView()
            case .safety:
                SafetyTutorialView()
            case .support:
                SupportView()
            case .settings:
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: $isScanning) {
            ScanningView(isScanning: $isScanning, isActiveRide: $isActiveRide, activeScooterIds: $activeScooterIds)
        }
        .fullScreenCover(isPresented: $isShowingParkingVerification) {
            ParkingVerificationView(
                isVisible: $isShowingParkingVerification,
                isActiveRide: $isActiveRide,
                scooterIds: activeScooterIds,
                rideData: lastTripData,
                userId: authViewModel.currentUser?.id
            )
        }
        .sheet(isPresented: $isShowingGroupRideSelection) {
            GroupRideSelectionView(isPresented: $isShowingGroupRideSelection) {
                isScanning = true
            } onReserve: {
                isShowingGroupRideSelection = false
                isGroupSelectionMode = true
                selectedScooter = nil
            }
            .presentationDetents([.height(350)])
        }
        .onChange(of: isActiveRide) { old, new in
            if !new {
                activeScooterIds.removeAll()
                if lastTripData != nil {
                    showTripSummary = true
                }
            }
        }
        .onAppear {
            scooterViewModel.currentUserId = authViewModel.currentUser?.id
            Task {
                await scooterViewModel.loadScooters()
            }
        }
        .onChange(of: authViewModel.currentUser?.id) { old, new in
            scooterViewModel.currentUserId = new
        }
    }
}

extension MenuItem: Identifiable {
    var id: String { self.rawValue }
}

struct PlaceholderView: View {
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").padding()
                    }
                    Spacer()
                }
                Spacer()
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                Text("Coming Soon")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
        }
    }
}

struct HeaderButton: View {
    let icon: String
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .foregroundColor(.white)
        }
    }
}
