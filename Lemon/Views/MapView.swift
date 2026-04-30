//
//  MapView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Binding var selectedScooter: Scooter?
    @Binding var isGroupSelectionMode: Bool
    @Binding var selectedGroupScooters: Set<Scooter>
    @ObservedObject var scooterViewModel: ScooterViewModel
    let scooters: [Scooter]
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -36.85361, longitude: 174.766481),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )))
    
    var body: some View {
        Map(position: $position) {
            if scooterViewModel.showAggregates && !scooterViewModel.aggregates.isEmpty {
                // Render Aggregates (Clusters)
                ForEach(scooterViewModel.aggregates) { aggregate in
                    Annotation("Cluster", coordinate: aggregate.coordinate) {
                        AggregateMarker(count: aggregate.count)
                            .onTapGesture {
                                // Zoom in when tapping a cluster
                                withAnimation {
                                    position = .region(MKCoordinateRegion(
                                        center: aggregate.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    ))
                                }
                            }
                    }
                }
            } else {
                // Render Individual Scooters
                ForEach(scooters) { scooter in
                    Annotation(scooter.displayName, coordinate: scooter.coordinate) {
                        ScooterMarker(
                            isSelected: isGroupSelectionMode ? selectedGroupScooters.contains(scooter) : selectedScooter == scooter,
                            isGroupMode: isGroupSelectionMode
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if isGroupSelectionMode {
                                    if selectedGroupScooters.contains(scooter) {
                                        selectedGroupScooters.remove(scooter)
                                    } else if selectedGroupScooters.count < 5 {
                                        selectedGroupScooters.insert(scooter)
                                    }
                                } else {
                                    selectedScooter = scooter
                                }
                            }
                        }
                    }
                }
            }
            UserAnnotation()
        }
        .onMapCameraChange { context in
            scooterViewModel.updateZoomLevel(latitudeDelta: context.region.span.latitudeDelta)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                withAnimation {
                    position = .userLocation(fallback: .automatic)
                }
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.bottom, 160) // Adjusted padding to sit above the bottom sheet area
            .padding(.trailing, 16)
        }
    }
}

struct ScooterMarker: View {
    let isSelected: Bool
    var isGroupMode: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
            // In group mode: Selected = LemonPrimary, Unselected = White (to prompt selection)
            // In normal mode: Selected = White, Unselected = LemonPrimary
                .fill(isSelected ? (isGroupMode ? Color.lemonPrimary : Color.white) : (isGroupMode ? Color.white : Color.lemonPrimary))
                .frame(width: 45, height: 45)
                .shadow(radius: 10)
            
            if isGroupMode && isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
            } else {
                Image(systemName: "scooter")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
    }
}

struct AggregateMarker: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.lemonPrimary)
                .frame(width: 40, height: 40)
                .shadow(radius: 5)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
            
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
        }
    }
}
