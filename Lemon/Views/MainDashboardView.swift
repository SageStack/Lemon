//
//  MainDashboardView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var scooterViewModel = ScooterViewModel()
    @StateObject private var viewModel = DashboardViewModel()
    
    @State private var selectedScooter: Scooter?
    @State private var reservedScooter: Scooter?
    @State private var selectedGroupScooters: Set<Scooter> = []
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                // Background Map
                MapView(
                    selectedScooter: $selectedScooter,
                    isGroupSelectionMode: $viewModel.isGroupSelectionMode,
                    selectedGroupScooters: $selectedGroupScooters,
                    scooterViewModel: scooterViewModel,
                    scooters: scooterViewModel.availableScooters
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: viewModel.isActiveRide ? 200 : 150)
                    }
                
                // UI Overlays
                VStack {
                    // Header
                    HStack {
                        HeaderButton(icon: "line.3.horizontal") {
                            viewModel.toggleSideMenu()
                        }
                        Spacer()
                        Text("LEMON")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .italic()
                            .tracking(3)
                        Spacer()
                        HeaderButton(icon: "person.fill") {
                            viewModel.selectedMenuItem = .profile
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom Control Panel
                    VStack(spacing: 20) {
                        switch viewModel.currentState {
                        case .groupSelection:
                            groupSelectionControls
                        case .activeRide:
                            ActiveRideView(isActive: $viewModel.isActiveRide, scooterIds: viewModel.activeScooterIds, allScooters: scooterViewModel.scooters)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        case .reservation:
                            if let scooter = reservedScooter {
                                ReservationView(scooter: scooter, isReserved: $viewModel.isReserved)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        case .normal:
                            normalControls
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

                }
            }
            .blur(radius: viewModel.isShowingSideMenu || viewModel.isShowingGroupRideSelection ? 10 : 0)
            .animation(.easeInOut(duration: 0.35), value: viewModel.isShowingSideMenu)
            .animation(.easeInOut(duration: 0.35), value: viewModel.isShowingGroupRideSelection)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReserveScooter"))) { notification in
                if let scooter = notification.object as? Scooter, let userId = authViewModel.currentUser?.id {
                    Task {
                        try? await ScooterService.shared.reserveScooter(id: scooter.id, userId: userId)
                        await MainActor.run {
                            withAnimation {
                                reservedScooter = scooter
                                viewModel.isReserved = true
                                selectedScooter = nil // Hide card
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnlockScooter"))) { _ in
                viewModel.isScanning = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestAddScooter"))) { _ in
                viewModel.isScanning = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestEndRide"))) { notification in
                if let data = notification.object as? TripData {
                    viewModel.lastTripData = data
                }
                viewModel.isShowingParkingVerification = true
            }
            .onChange(of: scooterViewModel.scooters) { old, new in
                // Active Ride Discovery
                guard !viewModel.isActiveRide, let userId = authViewModel.currentUser?.id else { return }
                
                let myScooters = new.filter { $0.currentRideClientId == userId }
                if !myScooters.isEmpty {
                    print("Realtime: 🔍 Discovered \(myScooters.count) active scooters for user. Restoring ride state.")
                    viewModel.activeScooterIds = myScooters.map { $0.id }
                    viewModel.isActiveRide = true
                }
            }
            
            // Side Menu
            SideMenuView(isShowing: $viewModel.isShowingSideMenu, selectedMenuItem: $viewModel.selectedMenuItem)
            
            // Custom Group Ride Selection Overlay
            ZStack(alignment: .bottom) {
                if viewModel.isShowingGroupRideSelection {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            viewModel.dismissGroupRideSelection()
                        }
                    
                    GroupRideSelectionView(isPresented: $viewModel.isShowingGroupRideSelection) {
                        viewModel.isScanning = true
                    } onReserve: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            viewModel.isShowingGroupRideSelection = false
                            viewModel.isGroupSelectionMode = true
                        }
                        selectedScooter = nil
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea()
            .zIndex(10)
        }
        .background(Color.lemonBackground)
        .alert("SECURITY ALERT", isPresented: $scooterViewModel.isSuspiciousMovementDetected) {
            Button("I'M HERE", role: .cancel) {
                scooterViewModel.isSuspiciousMovementDetected = false
            }
            Button("SOUND ALARM", role: .destructive) {
                // Trigger backend alarm
            }
        } message: {
            Text("Suspicious movement detected on a nearby scooter. Is this you?")
        }
        .sheet(isPresented: $viewModel.showTripSummary) {
            if let data = viewModel.lastTripData {
                TripSummaryView(duration: data.duration, cost: data.cost, scooterCount: data.count, distance: data.distance) {
                    viewModel.showTripSummary = false
                    viewModel.lastTripData = nil
                }
            }
        }
        .sheet(item: $viewModel.selectedMenuItem) { item in
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
        .fullScreenCover(isPresented: $viewModel.isScanning) {
            ScanningView(isScanning: $viewModel.isScanning, isActiveRide: $viewModel.isActiveRide, activeScooterIds: $viewModel.activeScooterIds)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingParkingVerification) {
            ParkingVerificationView(
                isVisible: $viewModel.isShowingParkingVerification,
                isActiveRide: $viewModel.isActiveRide,
                scooterIds: viewModel.activeScooterIds,
                rideData: viewModel.lastTripData,
                userId: authViewModel.currentUser?.id
            )
        }
        .onChange(of: viewModel.isActiveRide) { old, new in
            if new {
                // Start High-Precision tracking
                let earliestStart = scooterViewModel.scooters
                    .filter { viewModel.activeScooterIds.contains($0.id) }
                    .compactMap { $0.currentRideStart }
                    .min() ?? Date()
                scooterViewModel.startRideTracking(startTime: earliestStart)
            } else {
                scooterViewModel.stopRideTracking()
                viewModel.activeScooterIds.removeAll()
                if viewModel.lastTripData != nil {
                    viewModel.showTripSummary = true
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
        .onChange(of: scooterViewModel.availableScooters) { old, scooters in
            guard let userId = authViewModel.currentUser?.id else { return }
            
            // Auto-detect Active Ride
            let myActiveScooters = scooters.filter { $0.currentRideClientId == userId }
            if !myActiveScooters.isEmpty && !viewModel.isActiveRide {
                print("Dashboard: 🏁 Auto-detected active ride for user!")
                viewModel.isActiveRide = true
                viewModel.activeScooterIds = myActiveScooters.map { $0.id }
                
                // If a scooter was selected, clear it so the Active Ride UI takes precedence
                selectedScooter = nil
            }
        }
    }
    
    // MARK: - Subviews
    
    private var groupSelectionControls: some View {
        VStack(spacing: 16) {
            Text("Select up to 5 scooters")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text("\(selectedGroupScooters.count)/5 SELECTED")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.lemonPrimary)
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.isGroupSelectionMode = false
                    selectedGroupScooters.removeAll()
                }) {
                    Text("CANCEL")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.lemonGlassBackground)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    // Proceed with group reservation
                    viewModel.isGroupSelectionMode = false
                    viewModel.isReserved = true // Mock reservation
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
    }
    
    private var normalControls: some View {
        VStack(spacing: 16) {
            if let scooter = selectedScooter {
                ScooterCard(scooter: scooter)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.showGroupRideSelection()
                }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text("GROUP")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 120, height: 60)
                    .background(Color.lemonGlassBackground)
                    .cornerRadius(15)
                }
                
                ActionButton(title: "SCAN TO UNLOCK", icon: "qrcode.viewfinder") {
                    viewModel.isScanning = true
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

extension MainDashboardView {
    func setupObservers() -> some View {
        self
            .onChange(of: viewModel.isActiveRide) { old, new in
                if !new {
                    viewModel.activeScooterIds.removeAll()
                    if viewModel.lastTripData != nil {
                        viewModel.showTripSummary = true
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

struct HeaderButton: View {
    let icon: String
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .foregroundColor(.primary)
        }
    }
}
