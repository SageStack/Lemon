//
//  LoginView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false
    @State private var showAlert = false
    @State private var activeError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    Text("LEMON")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .italic()
                        .tracking(8)
                        .foregroundColor(.lemonPrimary)
                    
                    Text("URBAN MOBILITY")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Input Fields
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "EMAIL", text: $email, icon: "envelope")
                        .focused($focusedField, equals: .email)
                        .onTapGesture { focusedField = .email }
                    
                    CustomSecureField(placeholder: "PASSWORD", text: $password, icon: "lock")
                        .focused($focusedField, equals: .password)
                        .onTapGesture { focusedField = .password }
                }
                .padding(.horizontal, 30)
                
                // Login Button
                Button(action: {
                    Task {
                        await authViewModel.login(email: email, password: password)
                    }
                }) {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .padding(.trailing, 10)
                        }
                        Text("LOGIN")
                            .font(.system(size: 18, weight: .black))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.lemonPrimary)
                    .foregroundColor(.black)
                    .cornerRadius(15)
                    .shadow(color: .lemonPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 30)
                .disabled(authViewModel.isLoading)
                
                // OR divider
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Text("OR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 10)
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                .padding(.horizontal, 50)
                
                // Social Login Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await authViewModel.signInWithGoogle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill") // Placeholder, ideally use asset
                                .font(.system(size: 20))
                            Text("SIGN IN WITH GOOGLE")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        Task {
                             authViewModel.signInWithApple()
                        }
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                                .padding(.bottom, 2)
                            Text("SIGN IN WITH APPLE")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)
                .disabled(authViewModel.isLoading)
                
                // Signup Toggle
                Button(action: {
                    authViewModel.errorMessage = nil // Clear error when switching
                    showSignup = true
                }) {
                    Text("NEW TO LEMON? SIGN UP")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.lemonPrimary)
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showSignup) {
            SignupView()
                .environmentObject(authViewModel)
        }
        .alert("Auth Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { 
                authViewModel.errorMessage = nil
            }
        } message: {
            if let error = activeError {
                Text(error)
            }
        }
        .onChange(of: authViewModel.errorMessage) { oldValue, newValue in
            if let error = newValue, !showSignup {
                activeError = error
                showAlert = true
            } else {
                showAlert = false
            }
        }
    }
}

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.lemonPrimary)
                .frame(width: 30)
            
            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(.white.opacity(0.3))
                }
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .submitLabel(.next)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.lemonPrimary)
                .frame(width: 30)
            
            SecureField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(.white.opacity(0.3))
                }
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .submitLabel(.done)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
