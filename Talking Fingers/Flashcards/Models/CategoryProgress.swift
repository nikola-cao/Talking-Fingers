//
//  CategoryProgress.swift
//  Talking Fingers
//
//  The two percentages shown for a category, one per mode. They measure
//  different things on purpose: Learn is about coverage (how much of the
//  category you've met), Exercise is about depth (how well you know it), so a
//  category can sit at 100% learned and 0% exercised.
//

import Foundation

enum CategoryProgress {
    /// Share of the category's terms that have moved off `.new`, 0...100 —
    /// the same notion `CategoryUnlock` gates on. Reports 100 only when the
    /// category is genuinely complete, never rounding up to it.
    static func learned(_ category: TermCategory, flashcards: [FlashcardModel]) -> Int {
        let categoryCards = cards(for: category, in: flashcards)
        guard !categoryCards.isEmpty else { return 0 }

        let learnedCount = categoryCards.filter { $0.progress != .new }.count
        guard learnedCount < categoryCards.count else { return 100 }
        return min(99, Int(Double(learnedCount) / Double(categoryCards.count) * 100))
    }

    /// Mastery across the category, 0...100. Learn can't raise a card past
    /// `.learning`, so that's the floor here — this percentage only moves once
    /// Exercise starts polishing terms.
    static func exerciseMastery(_ category: TermCategory, flashcards: [FlashcardModel]) -> Int {
        let categoryCards = cards(for: category, in: flashcards)
        guard !categoryCards.isEmpty else { return 0 }

        let total = categoryCards.reduce(0.0) { runningTotal, card in
            switch card.progress {
            case .new, .learning: return runningTotal
            case .polishing:      return runningTotal + 50
            case .mastered:       return runningTotal + 100
            }
        }
        return Int((total / Double(categoryCards.count)).rounded())
    }

    /// Cards whose term actually belongs to their stored category, guarding
    /// against mismatched remote records.
    private static func cards(for category: TermCategory, in flashcards: [FlashcardModel]) -> [FlashcardModel] {
        flashcards.filter { $0.category == category && $0.term.category == category }
    }
}
