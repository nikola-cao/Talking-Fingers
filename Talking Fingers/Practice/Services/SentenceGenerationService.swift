//
//  SentenceGenerationService.swift
//  Talking Fingers
//
//  Generates AI practice sentences for a set of term categories. Used by
//  the New Practice sheet and by Extend inside a running session, so both
//  flows share the same allowed-category rules.
//

import Foundation

enum SentenceGenerationService {
    /// Categories the practice generator supports. Drives the New Practice
    /// picker and constrains Extend, so a session can never grow sentences
    /// from a category the user couldn't have picked.
    static let allowedCategories: [TermCategory] = TermCategory.allCases.filter { category in
        category != .commonDescriptors
        && category != .dateTime
        && category != .commonObjects
        && category != .feelingsEmotions
    }

    /// Generates 5 practice sentences for the given categories.
    /// An empty set means "all allowed categories"; anything outside
    /// `allowedCategories` is ignored.
    static func generateSentences(
        categories: Set<TermCategory>,
        modeSelection: PracticeModeSelection = PracticeModeSelection(signing: true, comprehension: false)
    ) async throws -> [AISentenceModel] {
        let allowed = Set(allowedCategories)
        let effectiveCategories = categories.isEmpty ? allowed : categories.intersection(allowed)

        // 1. Get all terms for the selected categories
        let focusTerms = effectiveCategories.flatMap { category in
            Term.words(for: category)
        }

        guard !focusTerms.isEmpty else {
            throw AIError.invalidRequest
        }

        // 2. Determine which terms should drive sentence generation.
        // If there are any non-alphabet/number terms, prioritize those for sentences.
        // If the user ONLY picked alphabet and/or numbers, still allow those terms
        // so we can generate spelling/number-focused practice.
        let nonAlphaNumericTerms = focusTerms.filter { term in
            term.category != .alphabet && term.category != .numbers
        }
        let sentenceTerms = nonAlphaNumericTerms.isEmpty ? focusTerms : nonAlphaNumericTerms

        // Create flashcards only for sentence-appropriate terms
        let flashcards = sentenceTerms.map { term in
            FlashcardModel(
                term: term,
                id: UUID(),
                category: term.category,
                gifFileName: nil
            )
        }

        // 3. Call AI generation with focus terms using the shared instance
        let aiViewModel = AIViewModel.shared

        // Wait for API key to be available (handles cold starts properly)
        try await aiViewModel.waitForAPIKey()

        let sentences = try await aiViewModel.generateAISentences(
            from: flashcards,
            focusTerms: sentenceTerms
        )

        // 4. Assign practiceType based on mode selection
        return assignPracticeTypes(to: sentences, modeSelection: modeSelection)
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
