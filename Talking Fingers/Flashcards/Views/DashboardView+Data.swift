//
//  DashboardView+Data.swift
//  Talking Fingers
//
//  Data derivation and category-gating helpers backing DashboardView's
//  sections on both platforms.
//

import SwiftUI
import SwiftData

extension DashboardView {
    // Compute categories that are in progress (have at least one non-new and non-mastered card)
    var inProgressCategories: [(category: TermCategory, progress: Float, mode: String)] {
        let grouped = Dictionary(grouping: categoryScopedCards) { $0.category }
        return grouped.compactMap { (category, _) in
            let learnedPercent = learnedPercentage(for: category)
            let exercisePercent = exerciseMasteryPercentage(for: category)
            let learnDone = isLearnCompleted(for: category)

            // Untouched, or finished outright — neither is something to
            // jump back into.
            guard learnedPercent > 0, !(learnDone && exercisePercent >= 100) else { return nil }

            // Each card reports the mode it's offering to continue: Learn
            // coverage until Learn is done, mastery afterwards. Deciding the
            // mode on Learn completion also stops this button opening an
            // Exercise the category hasn't unlocked yet.
            return (
                category: category,
                progress: Float(learnDone ? exercisePercent : learnedPercent),
                mode: learnDone ? "Exercise" : "Learn"
            )
        }
        .sorted { $0.progress > $1.progress }
        .prefix(2)
        .map { $0 }
    }

    var dailyQueue: DailyReviewQueue {
        flashcardVM.generateDailyReviewQueue(limit: 5)
    }

    // Cards successfully practiced today, capped at the daily target.
    var dailyChallengeCompleted: Int {
        let completedToday = flashcardVM.flashcards.filter { card in
            guard let last = card.lastSucceeded else { return false }
            return Calendar.current.isDateInToday(last)
        }.count
        return min(completedToday, dailyQueue.requestedLimit)
    }

    var currentStreak: Int {
        users.first?.streakCount ?? 0
    }

    var categoryScopedCards: [FlashcardModel] {
        // Guard against mismatched remote records: category views should only show
        // cards whose term actually belongs to that category.
        flashcardVM.flashcards.filter { $0.term.category == $0.category }
    }

    /// Share of the category's terms already seen in Learn.
    func learnedPercentage(for category: TermCategory) -> Int {
        CategoryProgress.learned(category, flashcards: categoryScopedCards)
    }

    /// Mastery across the category, which only Exercise can raise.
    func exerciseMasteryPercentage(for category: TermCategory) -> Int {
        CategoryProgress.exerciseMastery(category, flashcards: categoryScopedCards)
    }

    func isLearnCompleted(for category: TermCategory) -> Bool {
        CategoryUnlock.isLearnCompleted(category, flashcards: categoryScopedCards)
    }

    /// Categories open in a chain: alphabet and numbers from the start, then
    /// each one as everything listed before it is learned.
    func canAccessCategory(_ category: TermCategory) -> Bool {
        CategoryUnlock.canAccess(category, flashcards: categoryScopedCards)
    }

    func isExerciseUnlocked(for category: TermCategory) -> Bool {
        isLearnCompleted(for: category)
    }

    func loadUserFlashcardsIfNeeded() {
        guard flashcardVM.flashcards.isEmpty, !flashcardVM.isLoading else { return }
        Task {
            await flashcardVM.loadFlashcards(modelContext: modelContext)
        }
    }
}
