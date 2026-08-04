//
//  SavedPracticeModel.swift
//  Talking Fingers
//
//  Created by Aimee on 3/9/26.
//

import SwiftData
import Foundation

@Model
class SavedPracticeModel {
    var id: UUID
    var date: Date
    var sentencesData: Data
    var categories: [String]
    /// User-visible practice name from the New Practice sheet (`nil` for legacy rows).
    var title: String?

    /// When this practice was last changed locally (client time). Drives
    /// newest-action-wins merging against Firestore.
    var updatedAt: Date?
    /// True while a local change hasn't been confirmed uploaded to Firestore.
    var needsSync: Bool = false

    init(sentences: [AISentenceModel], categories: [String], title: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.sentencesData = (try? JSONEncoder().encode(sentences)) ?? Data()
        self.categories = categories
        self.title = title
        self.updatedAt = nil
        self.needsSync = false
    }

    /// Rebuilds a practice pulled from Firestore. Keeps the remote id so the
    /// same practice can't be inserted twice across devices.
    init(
        id: UUID,
        date: Date,
        sentencesData: Data,
        categories: [String],
        title: String?,
        updatedAt: Date?
    ) {
        self.id = id
        self.date = date
        self.sentencesData = sentencesData
        self.categories = categories
        self.title = title
        self.updatedAt = updatedAt
        self.needsSync = false
    }

    var sentences: [AISentenceModel] {
        get {
            (try? JSONDecoder().decode([AISentenceModel].self, from: sentencesData)) ?? []
        }
        set {
            sentencesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}
