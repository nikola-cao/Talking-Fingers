//
//  SentenceGenerating.swift
//  Talking Fingers
//
//  Common interface for practice-sentence sources. See
//  ON_DEVICE_SENTENCE_GENERATION_PLAN.md §3 — `SentenceGenerationService`
//  resolves one of these at call time (Foundation Models when the device
//  supports it, the bundled sentence bank everywhere else) rather than
//  hard-coding a single backend.
//

import Foundation

/// Compact replacement for the raw flashcard dump the old prompt used to
/// send verbatim (plan §5.3). Counts are scoped to the request's
/// `allowedTerms` only, so they reflect what this generation is actually
/// allowed to draw on.
struct LearningStateSummary {
    let newCount: Int
    let learningCount: Int
    let polishingCount: Int
    let masteredCount: Int
    let recentSuccessCount: Int

    /// Terms (within scope) the learner has already seen at least once —
    /// i.e. progress != `.new`. Used for the familiarity sort in §2.3; this
    /// is a ranking preference, never a filter.
    let familiarTerms: Set<Term>

    var total: Int { newCount + learningCount + polishingCount + masteredCount }

    init(flashcards: [FlashcardModel], allowedTerms: Set<Term>) {
        let scoped = flashcards.filter { allowedTerms.contains($0.term) }
        newCount = scoped.filter { $0.progress == .new }.count
        learningCount = scoped.filter { $0.progress == .learning }.count
        polishingCount = scoped.filter { $0.progress == .polishing }.count
        masteredCount = scoped.filter { $0.progress == .mastered }.count
        recentSuccessCount = scoped.filter {
            guard let date = $0.lastSucceeded else { return false }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? Int.max <= 7
        }.count
        familiarTerms = Set(scoped.filter { $0.progress != .new }.map(\.term))
    }

    /// Coarse learner profile, mirroring the original `analyzeLearningState` heuristic.
    var profileLabel: String {
        guard total > 0 else { return "BEGINNER" }
        let newRatio = Double(newCount) / Double(total)
        let masteredRatio = Double(masteredCount) / Double(total)
        let advancedRatio = Double(polishingCount + masteredCount) / Double(total)

        if newRatio >= 0.5 { return "BEGINNER" }
        if masteredRatio >= 0.6 { return "ADVANCED" }
        if advancedRatio >= 0.6 { return "NEAR_MASTERY" }
        if newRatio + Double(learningCount) / Double(total) >= 0.6 { return "BUILDING" }
        return "MIXED"
    }

    var summaryLine: String {
        "total:\(total) new:\(newCount) learning:\(learningCount) polishing:\(polishingCount) " +
        "mastered:\(masteredCount) recent_success:\(recentSuccessCount) profile:\(profileLabel)"
    }
}

protocol SentenceGenerating {
    /// Produces practice sentences whose gloss tokens are all members of
    /// `allowedTerms`.
    /// - Parameters:
    ///   - allowedTerms: the hard vocabulary constraint (plan §2). Every
    ///     token in every returned sentence's gloss must be a member.
    ///   - focusTerms: terms to prioritize within `allowedTerms` — the
    ///     learner's chosen categories, excluding the always-added personal
    ///     information union.
    ///   - learningState: a compact summary of the learner's progress,
    ///     already scoped to `allowedTerms`.
    ///   - count: how many sentences to try to produce.
    /// - Returns: up to `count` sentences; may return fewer, never invalid ones.
    func generateSentences(
        allowedTerms: Set<Term>,
        focusTerms: [Term],
        learningState: LearningStateSummary,
        count: Int
    ) async throws -> [AISentenceModel]
}
