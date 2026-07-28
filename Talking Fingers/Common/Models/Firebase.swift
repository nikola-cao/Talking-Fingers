//
//  FIrebase.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 1/27/26.
//

import Foundation
import Firebase

class Firebase {
    static let db = Firestore.firestore()

    /// The `Users` collection holding one profile document per uid.
    static var users: CollectionReference {
        db.collection("Users")
    }
}

/// Firestore field names for the `Users/{uid}` profile document, shared by
/// every reader/writer (AuthenticationViewModel, UserProfileService).
enum UserFields {
    static let userId = "userId"
    static let name = "name"
    static let email = "email"
    static let handedness = "handedness"
    static let streakCount = "streakCount"
    static let lastActivity = "lastActivity"
    static let profileUpdatedAt = "profileUpdatedAt"
}
