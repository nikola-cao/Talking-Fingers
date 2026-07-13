//
//  PracticeAttemptModel.swift
//  Talking Fingers
//

import Foundation
import SwiftData

@Model
class PracticeAttemptModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var termRawValue: String
    var categoryRawValue: String
    var correct: Bool

    init(term: Term, correct: Bool, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.termRawValue = term.rawValue
        self.categoryRawValue = term.category.rawValue
        self.correct = correct
    }

    var term: Term? { Term(rawValue: termRawValue) }
    var category: TermCategory? { TermCategory(rawValue: categoryRawValue) }
}
