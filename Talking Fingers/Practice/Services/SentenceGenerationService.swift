//
//  SentenceGenerationService.swift
//  Talking Fingers
//
//  Generates practice sentences for a set of term categories. Used by
//  the New Practice sheet and by Extend inside a running session, so both
//  flows share the same allowed-category rules.
//
//  Sentences come from the bundled sentence bank. `FoundationModelsGenerator`
//  is still in the tree behind a DEBUG-only override, but it is NOT used by
//  default: evaluation showed the on-device model producing structurally
//  valid but semantically wrong gloss ("GOOD MORNING ME", "NAME ME J") that
//  no cheap validator catches, whereas bank entries are correct by
//  construction and work on every device. See
//  ON_DEVICE_SENTENCE_GENERATION_PLAN.md §9 for the evaluation and what
//  would have to change to revisit it.
//

import Foundation
import FoundationModels

enum SentenceGenerationService {
    /// Categories the practice generator supports. Drives the New Practice
    /// picker and constrains Extend, so a session can never grow sentences
    /// from a category the user couldn't have picked. Also the set
    /// `VocabularyScope` scopes eligibility to — the sentence bank ships
    /// exactly one bank per category in this list, plus `.personalInformation`.
    static let allowedCategories: [TermCategory] = TermCategory.allCases.filter { category in
        category != .commonDescriptors
        && category != .dateTime
        && category != .commonObjects
        && category != .feelingsEmotions
    }

    /// How many sentences a practice session actually gets.
    private static let targetValidSentenceCount = 5

    /// Only the Foundation Models path over-requests. `SentenceValidation`
    /// discards structurally bad gloss (stranded question words, orphan
    /// letters, dangling possessives), so that backend has to generate more
    /// than it keeps. Bank entries are pre-validated at author time and are
    /// never discarded, so the bank asks for exactly what it needs — asking
    /// for more would mark unseen sentences as recently-served and burn
    /// through the rotation at twice the rate.
    private static let modelOverRequestCount = 10

    enum GenerationError: Error {
        /// No eligible vocabulary could be resolved for this request. In
        /// practice this shouldn't happen — `VocabularyScope` always falls
        /// back to `.greetings` — but stays as a safety net.
        case noEligibleVocabulary
    }

    #if DEBUG
    /// Debug-only backend pin. The bank is the default, so this exists to opt
    /// *into* Foundation Models when retesting it — e.g. after an OS update
    /// ships a stronger on-device model.
    ///
    /// Set it either way:
    ///   - Xcode scheme → Run → Arguments Passed On Launch:
    ///     `-SentenceBackendOverride foundationModels`
    ///     (UserDefaults reads `-key value` launch arguments automatically)
    ///   - `UserDefaults.standard.set("foundationModels", forKey: "SentenceBackendOverride")`
    ///
    /// `bank` is accepted so the value can be set explicitly, but it is also
    /// what you get with no override at all.
    enum BackendOverride: String {
        case bank
        case foundationModels

        static var current: BackendOverride? {
            UserDefaults.standard
                .string(forKey: "SentenceBackendOverride")
                .flatMap(BackendOverride.init(rawValue:))
        }
    }
    #endif

    /// Generates up to 5 practice sentences for the given categories and the
    /// learner's real flashcard progress.
    /// - Parameters:
    ///   - categories: categories the learner explicitly picked. An empty
    ///     set falls back to whatever the learner has already studied
    ///     (plan §2.1), or `.greetings` for a day-one learner (§2.5).
    ///   - flashcards: the learner's real SwiftData flashcards — must NOT be
    ///     fabricated (plan §2.6); pass `SwiftDataVM.fetchFlashcards()`.
    static func generateSentences(
        categories: Set<TermCategory>,
        flashcards: [FlashcardModel],
        modeSelection: PracticeModeSelection = PracticeModeSelection(signing: true, comprehension: false)
    ) async throws -> [AISentenceModel] {
        let scope = VocabularyScope.resolve(chosenCategories: categories, flashcards: flashcards)
        guard !scope.allowedTerms.isEmpty else {
            throw GenerationError.noEligibleVocabulary
        }

        let focusTerms = Term.allCases.filter { scope.eligibleCategories.contains($0.category) }
        let learningState = LearningStateSummary(flashcards: flashcards, allowedTerms: scope.allowedTerms)

        log("scope: \(scope.eligibleCategories.map(\.rawValue).sorted().joined(separator: ", ")) "
            + "(\(scope.allowedTerms.count) allowed terms)"
            + (categories.isEmpty ? " — no categories chosen, derived from progress" : ""))

        let sentences = try await generateWithFallback(
            allowedTerms: scope.allowedTerms,
            focusTerms: focusTerms,
            learningState: learningState
        )

        // Defense in depth (plan §2.7): even though every generator is
        // expected to honor `allowedTerms` on its own, re-check membership
        // here so a misbehaving backend can never leak an out-of-scope term.
        let validSentences = sentences.filter { Set($0.gloss).isSubset(of: scope.allowedTerms) }
        let limited = Array(validSentences.prefix(targetValidSentenceCount))

        return assignPracticeTypes(to: limited, modeSelection: modeSelection)
    }

    private static func generateWithFallback(
        allowedTerms: Set<Term>,
        focusTerms: [Term],
        learningState: LearningStateSummary
    ) async throws -> [AISentenceModel] {
        #if DEBUG
        if BackendOverride.current == .foundationModels {
            log("Foundation Models pinned by debug override")
            switch SystemLanguageModel.default.availability {
            case .available:
                // Deliberately not caught: when you've pinned this backend you
                // want to see the failure, not a silent fallback to the bank.
                return try await FoundationModelsGenerator().generateSentences(
                    allowedTerms: allowedTerms,
                    focusTerms: focusTerms,
                    learningState: learningState,
                    count: modelOverRequestCount
                )
            case .unavailable(let reason):
                log("…but Foundation Models is unavailable (\(describe(reason))) — using the bank")
            @unknown default:
                log("…but Foundation Models availability is unrecognized — using the bank")
            }
        }
        #endif

        return try await bankSentences(allowedTerms, focusTerms, learningState)
    }

    private static func bankSentences(
        _ allowedTerms: Set<Term>,
        _ focusTerms: [Term],
        _ learningState: LearningStateSummary
    ) async throws -> [AISentenceModel] {
        let sentences = try await SentenceBankGenerator.shared.generateSentences(
            allowedTerms: allowedTerms,
            focusTerms: focusTerms,
            learningState: learningState,
            count: targetValidSentenceCount
        )
        log("served \(sentences.count) sentence(s) from the sentence bank")
        return sentences
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "device not eligible — needs iPhone 15 Pro or newer, or Apple silicon"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off in System Settings"
        case .modelNotReady:
            return "model not ready — likely still downloading"
        @unknown default:
            return "unrecognized reason"
        }
    }

    private static func log(_ message: String) {
        print("[SentenceGeneration] \(message)")
    }

    /// Assigns practiceType to sentences based on the user's mode selection.
    /// - Both modes: first half signing, second half comprehension
    /// - Signing only: all .words
    /// - Comprehension only: all .comprehension
    private static func assignPracticeTypes(
        to sentences: [AISentenceModel],
        modeSelection: PracticeModeSelection
    ) -> [AISentenceModel] {
        guard !sentences.isEmpty else { return sentences }

        if modeSelection.signing && modeSelection.comprehension {
            // Split roughly half-and-half
            let halfIndex = sentences.count / 2
            return sentences.enumerated().map { index, sentence in
                var s = sentence
                s.practiceType = index < halfIndex ? .words : .comprehension
                return s
            }
        } else if modeSelection.comprehension {
            return sentences.map { sentence in
                var s = sentence
                s.practiceType = .comprehension
                return s
            }
        } else {
            // signing only (default)
            return sentences.map { sentence in
                var s = sentence
                s.practiceType = .words
                return s
            }
        }
    }
}
