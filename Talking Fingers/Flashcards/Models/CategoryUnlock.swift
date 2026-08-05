//
//  CategoryUnlock.swift
//  Talking Fingers
//
//  The two gates on a category, in one place so they can't drift apart:
//
//  - Home unlocks categories in a chain. Alphabet and numbers are open from
//    day one; every later category waits until each one before it has been
//    learned, so the deck opens up in the order it's listed.
//  - Practice only offers a category once its own Learn is done, with the
//    three foundation categories opening as a group — otherwise a day-one
//    learner could build a practice out of nothing but the alphabet.
//

import Foundation

enum CategoryUnlock {
    /// The order categories open in on home. `TermCategory.allCases` is also
    /// the order they're listed in, so the grid unlocks top to bottom.
    static var progression: [TermCategory] { TermCategory.allCases }

    /// Open from day one — there's nothing to learn before them.
    static let startingCategories: [TermCategory] = [.alphabet, .numbers]

    /// Locked as a group in Practice: none of these opens until every one of
    /// them has been learned.
    static let foundationCategories: [TermCategory] = [.alphabet, .numbers, .personalInformation]

    /// A category counts as learned once *every* one of its terms has moved
    /// off `.new` — a Learn round only covers 10 terms, so a bigger category
    /// takes several rounds to clear. Cards whose term doesn't actually belong
    /// to their stored category are ignored, guarding against mismatched
    /// remote records.
    static func isLearnCompleted(_ category: TermCategory, flashcards: [FlashcardModel]) -> Bool {
        let categoryCards = flashcards.filter { card in
            card.category == category && card.term.category == category
        }
        return !categoryCards.isEmpty && categoryCards.allSatisfy { $0.progress != .new }
    }

    /// Share of the category's terms that have moved off `.new`, 0...100.
    /// Reports 100 only when the category is genuinely complete — never
    /// rounds up to it — since 100% is what opens the next category.
    static func learnedPercentage(_ category: TermCategory, flashcards: [FlashcardModel]) -> Int {
        let categoryCards = flashcards.filter { card in
            card.category == category && card.term.category == category
        }
        guard !categoryCards.isEmpty else { return 0 }

        let learnedCount = categoryCards.filter { $0.progress != .new }.count
        guard learnedCount < categoryCards.count else { return 100 }
        return min(99, Int(Double(learnedCount) / Double(categoryCards.count) * 100))
    }

    // MARK: - Home

    /// Whether home lets the learner open this category at all.
    static func canAccess(_ category: TermCategory, flashcards: [FlashcardModel]) -> Bool {
        if startingCategories.contains(category) { return true }
        guard let index = progression.firstIndex(of: category) else { return false }
        return progression[..<index].allSatisfy { isLearnCompleted($0, flashcards: flashcards) }
    }

    /// The category a just-finished Learn round has opened up, if any. That's
    /// the next one along the chain — skipping the starting categories, which
    /// were never locked — and only when it isn't already learned, so
    /// replaying an old category doesn't announce anything.
    static func categoryUnlocked(byLearning category: TermCategory, flashcards: [FlashcardModel]) -> TermCategory? {
        guard let index = progression.firstIndex(of: category) else { return nil }
        guard let next = progression[(index + 1)...].first(where: { !startingCategories.contains($0) }) else { return nil }
        guard canAccess(next, flashcards: flashcards),
              !isLearnCompleted(next, flashcards: flashcards) else { return nil }
        return next
    }

    /// The next category the learner has to finish before `category` opens,
    /// or `nil` when it's already accessible.
    static func nextPrerequisite(for category: TermCategory, flashcards: [FlashcardModel]) -> TermCategory? {
        if startingCategories.contains(category) { return nil }
        guard let index = progression.firstIndex(of: category) else { return nil }
        return progression[..<index].first { !isLearnCompleted($0, flashcards: flashcards) }
    }

    // MARK: - Practice

    static func foundationsCompleted(flashcards: [FlashcardModel]) -> Bool {
        foundationCategories.allSatisfy { isLearnCompleted($0, flashcards: flashcards) }
    }

    /// Nothing is practiceable until all three foundation categories are
    /// learned — stated here rather than left to the home chain to imply, so
    /// reordering `progression` can't quietly open Practice early. After that
    /// the three open together and everything else waits on its own Learn.
    static func isUnlockedForPractice(_ category: TermCategory, flashcards: [FlashcardModel]) -> Bool {
        guard foundationsCompleted(flashcards: flashcards) else { return false }
        if foundationCategories.contains(category) { return true }
        return isLearnCompleted(category, flashcards: flashcards)
    }

    /// Filters `categories` down to the ones Practice will offer, preserving
    /// order. Resolves the foundation rule once instead of per category.
    static func unlockedForPractice(
        from categories: [TermCategory],
        flashcards: [FlashcardModel]
    ) -> [TermCategory] {
        guard foundationsCompleted(flashcards: flashcards) else { return [] }
        return categories.filter { category in
            foundationCategories.contains(category)
                || isLearnCompleted(category, flashcards: flashcards)
        }
    }
}
