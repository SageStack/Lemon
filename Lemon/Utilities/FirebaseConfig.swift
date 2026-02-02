//
//  FirebaseConfig.swift
//  Lemon
//
//  Created by Antigravity on 02/02/2026.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class FirebaseManager {
    static let shared = FirebaseManager()
    
    // Note: User needs to add Firebase to the project via Swift Package Manager
    // and add the GoogleService-Info.plist to the project.
    
    private init() {
        // App now configured in LemonApp.swift
    }
    
    var auth: Auth {
        Auth.auth()
    }
    
    var db: Firestore {
        Firestore.firestore()
    }
    
    // Future: Add Storage or Functions if needed
}
