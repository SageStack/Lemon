//
//  AuthViewModel.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
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
    
    override init() {
        super.init()
        // Initialize from UserDefaults for the first frame
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        print("Auth: AuthViewModel Initialized (Previously Authenticated: \(self.isAuthenticated))")
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
        GIDSignIn.sharedInstance.handle(url)
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
    
    // MARK: - Google Sign In
    @MainActor
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
             errorMessage = "Could not get Client ID from Firebase configuration."
             return
        }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow!
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "Could not find root view controller."
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                errorMessage = "Could not get ID Token."
                return
            }
            let accessToken = user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)
            
            // Sign in to Firebase with the Google credential
            let authResult = try await auth.signIn(with: credential)
            print("User signed in with Google: \(authResult.user.email ?? "")")
             
        } catch {
            errorMessage = sanitizeError(error)
        }
    }
    
    // MARK: - Apple Sign In
    
    // Unhashed nonce.
    // Adapted from https://firebase.google.com/docs/auth/ios/apple
    private var currentNonce: String?

    @MainActor
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      let charset: Array<Character> =
          Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      var result = ""
      var remainingLength = length

      while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
          var random: UInt8 = 0
          let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
          if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
          }
          return random
        }

        randoms.forEach { random in
          if remainingLength == 0 {
            return
          }

          if random < charset.count {
            result.append(charset[Int(random)])
            remainingLength -= 1
          }
        }
      }

      return result
    }

    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
      }.joined()

      return hashString
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
            self.currentUser = User(
                id: user.uid,
                name: user.displayName ?? "User",
                email: user.email ?? ""
            )
        } else {
            print("Auth: Updating state to UNAUTHENTICATED")
            self.isAuthenticated = false
            self.currentUser = nil
        }
        
        // Sync with UserDefaults for RootView gate
        UserDefaults.standard.set(self.isAuthenticated, forKey: "isAuthenticated")
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

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
        guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identity token")
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        Task {
            do {
                let result = try await auth.signIn(with: credential)
                print("User signed in with Apple: \(result.user.email ?? "")")
                // If this is the first time, we might want to update the display name if available from appleIDCredential.fullName
                if let fullName = appleIDCredential.fullName,
                   let givenName = fullName.givenName,
                   let familyName = fullName.familyName {
                    let displayName = "\(givenName) \(familyName)"
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            } catch {
                print("Error signing in with Apple: \(error)")
                await MainActor.run {
                    self.errorMessage = sanitizeError(error)
                }
            }
        }
    }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    // Handle error.
    print("Sign in with Apple errored: \(error)")
    self.errorMessage = sanitizeError(error)
  }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
