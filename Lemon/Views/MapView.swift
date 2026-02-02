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
    let scooters: [Scooter]
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    ))
    
    var body: some View {
        Map(position: $position) {
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
            UserAnnotation()
        }
        // FIXED: Swapped 'emphasis' and 'pointsOfInterest' order
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
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
