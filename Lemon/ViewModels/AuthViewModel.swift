//
//  AuthViewModel.swift
//  Lemon
//
//  Created by Antigravity on 06/01/2026.
//

import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = UserDefaults.standard.bool(forKey: "isAuthenticated")
    @Published var isLoading = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var verificationEmailSent = false
    
    struct User {
        let id: String
        let name: String
        let email: String
    }
    
    private let auth = FirebaseManager.shared.auth
    private var authStateSubscription: AuthStateDidChangeListenerHandle?
    
    init() {
        print("Auth: AuthViewModel Initialized")
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateSubscription = auth.addStateDidChangeListener { [weak self] _, user in
            print("Auth: State change event")
            guard let self = self else { return }
            Task { @MainActor in
                self.updateAuthState(user: user)
            }
        }
    }
    
    @MainActor
    func checkSession() {
        print("Auth: Checking session...")
        updateAuthState(user: auth.currentUser)
    }
    
    @MainActor
    func login(email: String, password: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Detach strict background work
        do {
            // Note: firebased auth methods are async and thus non-blocking,
            // but explicitly detaching ensures main thread is free immediately.
            try await Task.detached(priority: .userInitiated) {
                _ = try await self.auth.signIn(withEmail: email, password: password)
            }.value
            
            // State is updated by setupAuthStateListener
        } catch {
            errorMessage = sanitizeError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func signup(name: String, email: String, password: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 8 characters long."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Detach strict background work
            try await Task.detached(priority: .userInitiated) {
                let result = try await self.auth.createUser(withEmail: email, password: password)
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }.value
            
            // State is updated by setupAuthStateListener
        } catch {
            errorMessage = sanitizeError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func signInWithMagicLink(email: String) async {
        // Firebase Passwordless Login requires different setup (ActionCodeSettings)
        // For simplicity during migration, we'll keep it as a placeholder or use standard login
        errorMessage = "Magic link sign-in is not yet configured for Firebase."
    }
    
    @MainActor
    func handle(url: URL) {
        // Firebase handles dynamic links through the AppDelegate/SceneDelegate
        // No specific handle(url) call needed here for basic Auth
    }
    
    @MainActor
    func logout() async {
        do {
            try auth.signOut()
            // State is updated by setupAuthStateListener
        } catch {
            errorMessage = sanitizeError(error)
        }
    }
    
    private func sanitizeError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()
        
        if description.contains("invalid login credentials") || description.contains("wrong-password") {
            return "The email or password you entered is incorrect."
        } else if description.contains("network connection lost") || description.contains("offline") {
            return "Please check your internet connection and try again."
        } else if description.contains("email already in use") || description.contains("email-already-in-use") {
            return "An account with this email already exists."
        } else {
            return error.localizedDescription
        }
    }
    
    private func updateAuthState(user: FirebaseAuth.User?) {
        if let user = user {
            print("Auth: Updating state to AUTHENTICATED")
            self.isAuthenticated = true
            UserDefaults.standard.set(true, forKey: "isAuthenticated")
            self.currentUser = User(
                id: user.uid,
                name: user.displayName ?? "User",
                email: user.email ?? ""
            )
        } else {
            print("Auth: Updating state to UNAUTHENTICATED")
            self.isAuthenticated = false
            UserDefaults.standard.set(false, forKey: "isAuthenticated")
            self.currentUser = nil
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
    }
    
    deinit {
        if let handle = authStateSubscription {
            auth.removeStateDidChangeListener(handle)
        }
    }
}
