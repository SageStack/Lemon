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
import FirebaseDatabase
import FirebaseStorage

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
    
    var rtdb: DatabaseReference {
        Database.database().reference()
    }
    
    var storage: Storage {
        Storage.storage()
    }
    
    // Cloud Functions Configuration
    var functionsBaseUrl: String {
        return "https://us-central1-lemon-app-final-prod-1.cloudfunctions.net"
    }
}
