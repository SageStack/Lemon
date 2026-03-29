//
//  SupportView.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import Combine

struct SupportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var chatMessage = ""
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color.lemonGlassBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("SUPPORT")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().frame(width: 40).opacity(0)
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        Text("HOW CAN WE HELP?")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.lemonPrimary)
                            .cornerRadius(30)
                            .padding(.top)
                        
                        FAQRow(question: "How do I start a ride?", answer: "Scan the QR code on the scooter using the 'Scan to Unlock' button on the home screen.")
                        FAQRow(question: "Where can I park?", answer: "Park in designated zones or on sidewalks without blocking pedestrians. Follow local laws.")
                        FAQRow(question: "My scooter won't unlock.", answer: "Ensure you have a valid payment method and good internet connection. Contact support if issues persist.")
                        
                        Spacer(minLength: 50)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("CHAT WITH US")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                            
                            HStack {
                                TextField("TYPE YOUR MESSAGE...", text: $chatMessage)
                                    .font(.system(size: 14))
                                Button(action: { chatMessage = "" }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.lemonPrimary)
                                }
                            }
                            .padding()
                            .background(Color.lemonCardBackground)
                            .cornerRadius(15)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(question)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.lemonPrimary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            
            Divider().background(Color.lemonSeparator)
        }
    }
}
