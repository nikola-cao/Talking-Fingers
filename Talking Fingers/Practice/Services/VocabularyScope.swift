//
//  VocabularyScope.swift
//  Talking Fingers
//
//  Computes which categories and terms a sentence-generation request may
//  draw vocabulary from. See ON_DEVICE_SENTENCE_GENERATION_PLAN.md §2 —
//  scoping happens at category granularity, not per exact term, and
//  `.personalInformation` is always unioned in because it carries the
//  pronouns and verbs every other category's nouns need to form a sentence.
//

import Foundation

enum VocabularyScope {
    struct Result {
        /// The categories the request is scoped to, before the always-on
        /// `.personalInformation` union. Used to build `focusTerms`.
        let eligibleCategories: Set<TermCategory>
        /// `eligibleCategories` plus `.personalInformation` — the set a bank
        /// sentence's owning category must belong to (§4.2), and the basis
        /// for `allowedTerms`.
        let categoriesForVocabulary: Set<TermCategory>
        /// Every term a generated sentence's gloss may use. The hard
        /// constraint enforced at the prompt/schema, bank-query, and
        /// validation layers (§2.7).
        let allowedTerms: Set<Term>
    }

    /// - Parameters:
    ///   - chosenCategories: categories the learner explicitly picked (New
    ///     Practice / Extend). Empty means "no explicit choice" — fall back
    ///     to whatever the learner has already studied.
    ///   - flashcards: the learner's real flashcard progress. Must be actual
    ///     SwiftData-backed cards, not fabricated ones — see plan §2.6.
    static func resolve(
        chosenCategories: Set<TermCategory>,
        flashcards: [FlashcardModel]
    ) -> Result {
        let supported = Set(SentenceGenerationService.allowedCategories)

        let eligibleCategories: Set<TermCategory>
        if !chosenCategories.isEmpty {
            eligibleCategories = chosenCategories.intersection(supported)
        } else {
            let studiedCategories = Set(
                flashcards
                    .filter { $0.progress != .new }
                    .map(\.category)
            ).intersection(supported)
            // Day-one learner: nothing studied yet. Greetings is the only
            // fallback needed (§2.5) — the category-level rule above already
            // removes every other empty-pool case.
            eligibleCategories = studiedCategories.isEmpty ? [.greetings] : studiedCategories
        }

        let categoriesForVocabulary = eligibleCategories.union([.personalInformation])
        let allowedTerms = Set(categoriesForVocabulary.flatMap { Term.words(for: $0) })

        return Result(
            eligibleCategories: eligibleCategories,
            categoriesForVocabulary: categoriesForVocabulary,
            allowedTerms: allowedTerms
        )
    }
}
