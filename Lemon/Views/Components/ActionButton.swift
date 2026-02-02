//
//  ActionButton.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.lemonPrimary)
            .cornerRadius(16)
            .shadow(color: Color.lemonPrimary.opacity(0.4), radius: 12, y: 6)
        }
    }
}
