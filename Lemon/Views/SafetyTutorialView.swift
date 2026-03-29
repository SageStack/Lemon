//
//  SafetyTutorialView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct SafetyTutorialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    
    let tips = [
        SafetyTip(title: "WEAR A HELMET", description: "Safety first! Always wear a helmet to protect yourself while riding.", icon: "person.fill.viewfinder"),
        SafetyTip(title: "RIDE IN BIKE LANES", description: "Use bike lanes whenever available. Avoid riding on sidewalks to keep pedestrians safe.", icon: "bicycle"),
        SafetyTip(title: "OBEY TRAFFIC LAWS", description: "Stop at red lights and follow all local traffic signals and signs.", icon: "exclamationmark.octagon.fill"),
        SafetyTip(title: "PARK RESPONSIBLY", description: "Don't block sidewalks or ramps. Park in designated zones when possible.", icon: "parkingsign.circle.fill")
    ]
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color.lemonGlassBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                TabView(selection: $currentPage) {
                    ForEach(0..<tips.count, id: \.self) { index in
                            VStack(spacing: 40) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.05))
                                        .frame(width: 200, height: 200)
                                    
                                    Image(systemName: tips[index].icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.lemonPrimary)
                                }
                                
                                VStack(spacing: 15) {
                                    Text(tips[index].title)
                                        .font(.system(size: 24, weight: .black, design: .monospaced))
                                        .multilineTextAlignment(.center)
                                    
                                    Text(tips[index].description)
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    .onAppear {
                        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Color.lemonPrimary)
                        UIPageControl.appearance().pageIndicatorTintColor = UIColor.gray.withAlphaComponent(0.3)
                    }
                
                Button(action: {
                    if currentPage < tips.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        dismiss()
                    }
                }) {
                    Text(currentPage < tips.count - 1 ? "NEXT" : "GOT IT!")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.lemonPrimary)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

struct SafetyTip {
    let title: String
    let description: String
    let icon: String
}
