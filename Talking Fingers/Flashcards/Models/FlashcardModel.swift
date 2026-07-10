//
//  FlashcardModel.swift
//  Talking Fingers
//
//  Created by Isha Jain on 1/29/26.
//
import Foundation
import SwiftData

@Model
class FlashcardModel {
    @Attribute(.unique) var id: UUID
    var term: Term
    var lastSucceeded: Date?
    var starred: Bool
    var progress: ProgressType
    var category: TermCategory
    var gifFileName: String?

    /// When the user last changed this card's progress/starred state (on any device).
    /// Used for newest-action-wins merging during sync.
    var progressUpdatedAt: Date?
    /// True while a local change has not been confirmed uploaded to Firestore.
    var needsSync: Bool = false

    init(term: Term, id: UUID, lastSucceeded: Date? = nil, starred: Bool = false, progress: ProgressType = .new, category: TermCategory, gifFileName: String? = nil) {
        self.term = term
        self.id = id
        self.lastSucceeded = lastSucceeded
        self.starred = starred
        self.progress = progress
        self.category = category
        self.gifFileName = gifFileName ?? term.defaultGifFileName
        self.progressUpdatedAt = nil
        self.needsSync = false
    }

    /// Call after any user-initiated change to progress/starred state so the
    /// change is timestamped and queued for upload.
    func markProgressChanged() {
        progressUpdatedAt = Date()
        needsSync = true
    }
}
