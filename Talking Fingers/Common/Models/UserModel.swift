//
//  UserModel.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 1/27/26.
//

import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var userId: String
    var name: String
    var email: String
    var password: String
    var birthday: Date
    var handedness: String? // "left" or "right"
    
    @Relationship(deleteRule: .cascade)
    var flashcards: [FlashcardModel]
    
    var unlockedCategories: [String]
    var streakCount: Int = 0
    var lastActivity: Date?
    /// When profile or streak fields were last changed locally.
    var profileUpdatedAt: Date?
    /// True while local profile changes haven't been confirmed uploaded to Firestore.
    var needsProfileSync: Bool = false
    
    init(userId: String, name: String, email: String, handedness: String? = nil) {
        self.userId = userId
        self.name = name
        self.email = email
        self.password = ""
        self.birthday = Date()
        self.flashcards = []
        self.unlockedCategories = []
        self.streakCount = 0
        self.lastActivity = nil
        self.profileUpdatedAt = nil
        self.needsProfileSync = false
        self.handedness = handedness
    }
}
