//
//  PracticeCategoryUnlock.swift
//  Talking Fingers
//
//  Decides which categories the New Practice picker lets a learner choose.
//  Practice is gated on Learn: a category opens once its Learn cards have
//  been started, except for the three foundation categories, which stay
//  locked until all three are learned and then open together — otherwise a
//  day-one learner could build a practice out of nothing but the alphabet.
//

import Foundation

enum PracticeCategoryUnlock {
    /// Locked as a group: none of these unlocks until every one of them has
    /// been learned.
    static let foundationCategories: [TermCategory] = [.alphabet, .numbers, .personalInformation]

    /// Same rule DashboardView uses: a category counts as learned once any of
    /// its cards has moved off `.new`. Cards whose term doesn't actually
    /// belong to their stored category are ignored, guarding against
    /// mismatched remote records.
    static func isLearnCompleted(_ category: TermCategory, flashcards: [FlashcardModel]) -> Bool {
        flashcards.contains { card in
            card.category == category && card.term.category == category && card.progress != .new
        }
    }

    static func foundationsCompleted(flashcards: [FlashcardModel]) -> Bool {
        foundationCategories.allSatisfy { isLearnCompleted($0, flashcards: flashcards) }
    }

    static func isUnlocked(_ category: TermCategory, flashcards: [FlashcardModel]) -> Bool {
        if foundationCategories.contains(category) {
            return foundationsCompleted(flashcards: flashcards)
        }
        return isLearnCompleted(category, flashcards: flashcards)
    }

    /// Filters `categories` down to the unlocked ones, preserving order.
    /// Resolves the foundation rule once instead of per category.
    static func unlockedCategories(
        from categories: [TermCategory],
        flashcards: [FlashcardModel]
    ) -> [TermCategory] {
        let foundationsDone = foundationsCompleted(flashcards: flashcards)
        return categories.filter { category in
            foundationCategories.contains(category)
                ? foundationsDone
                : isLearnCompleted(category, flashcards: flashcards)
        }
    }
}
