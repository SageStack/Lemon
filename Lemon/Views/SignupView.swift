//
//  SignupView.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false
    @State private var activeError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password
    }
    
    var body: some View {
        ZStack {
            Color.lemonBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: { 
                        authViewModel.errorMessage = nil
                        dismiss() 
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("CREATE ACCOUNT")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.lemonPrimary)
                    
                    Text("Join the Lemon community and start riding.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "FULL NAME", text: $name, icon: "person")
                        .focused($focusedField, equals: .name)
                        .onTapGesture { focusedField = .name }
                    
                    CustomTextField(placeholder: "EMAIL", text: $email, icon: "envelope")
                        .focused($focusedField, equals: .email)
                        .onTapGesture { focusedField = .email }
                    
                    CustomSecureField(placeholder: "PASSWORD", text: $password, icon: "lock")
                        .focused($focusedField, equals: .password)
                        .onTapGesture { focusedField = .password }
                }
                
                Button(action: {
                    Task {
                        await authViewModel.signup(name: name, email: email, password: password)
                    }
                }) {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .padding(.trailing, 10)
                        }
                        Text("SIGN UP")
                            .font(.system(size: 18, weight: .black))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.lemonPrimary)
                    .foregroundColor(.black)
                    .cornerRadius(15)
                }
                .disabled(authViewModel.isLoading)
                
                Spacer()
            }
            .padding(30)
        }
        .alert("Auth Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                authViewModel.errorMessage = nil
            }
        } message: {
            if let error = activeError {
                Text(error)
            }
        }
        .alert("SUCCESS", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { 
                authViewModel.verificationEmailSent = false
                dismiss()
            }
        } message: {
            Text("Verification email sent! Please check your inbox to activate your account.")
        }
        .onChange(of: authViewModel.errorMessage) { oldValue, newValue in
            if let error = newValue {
                activeError = error
                showErrorAlert = true
            } else {
                showErrorAlert = false
            }
        }
        .onChange(of: authViewModel.verificationEmailSent) { oldValue, newValue in
            showSuccessAlert = newValue
        }
    }
}
