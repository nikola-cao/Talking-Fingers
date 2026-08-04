//
//  SentenceValidation.swift
//  Talking Fingers
//
//  Shared gloss tokenization/normalization used by every sentence generator.
//  Moved out of the old Claude-backed AIViewModel so both the on-device
//  Foundation Models path and any future backend can reuse the same rules
//  (plan §1.3, §5.5). The sentence bank doesn't need this — its entries are
//  pre-tokenized and validated at author time (see Tools/validate_sentence_bank.swift).
//

import Foundation

enum SentenceValidation {
    /// Converts raw (english, gloss-string) pairs into validated
    /// `AISentenceModel`s, keeping only sentences whose gloss tokens are all
    /// members of `allowedTerms`, deduplicating on English text and gloss
    /// sequence, and normalizing first-person pronouns.
    static func convertToAISentences(
        _ rawSentences: [(english: String?, gloss: String)],
        allowedTerms: Set<Term>,
        targetCount: Int
    ) -> [AISentenceModel] {
        let allowedTokenSet = Set(allowedTerms.map(\.rawValue))
        var aiSentences: [AISentenceModel] = []
        var seenEnglishKeys: Set<String> = []
        var seenGlossKeys: Set<String> = []

        for raw in rawSentences {
            let glossWordStrings = normalizeFirstPersonPronouns(in: tokenizeGloss(raw.gloss))
            guard !glossWordStrings.isEmpty else { continue }
            guard glossWordStrings.allSatisfy({ allowedTokenSet.contains($0) }) else { continue }

            let glossTerms = Term.fromStrings(glossWordStrings)
            guard glossTerms.count == glossWordStrings.count else { continue }
            guard isStructurallyValid(glossTerms) else { continue }

            let displaySentence = raw.english ?? raw.gloss

            // Drop duplicates (same English text or same gloss sequence) —
            // without this, a narrow focus-term prompt can produce
            // back-to-back identical practice sentences.
            let englishKey = displaySentence
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let glossKey = glossTerms.map(\.rawValue).joined(separator: " ")
            if seenEnglishKeys.contains(englishKey) || seenGlossKeys.contains(glossKey) {
                continue
            }
            seenEnglishKeys.insert(englishKey)
            seenGlossKeys.insert(glossKey)

            aiSentences.append(
                AISentenceModel(
                    sentence: displaySentence,
                    score: nil,
                    practiceType: .words,
                    gloss: glossTerms,
                    completed: false
                )
            )

            if aiSentences.count == targetCount { break }
        }

        return aiSentences
    }

    /// Subject and possessive pronouns are distinct signs — see the glossing
    /// rules in `PromptGenerator`. A gloss may not end on a possessive,
    /// because a possessive has to own the noun that follows it.
    private static let possessives: Set<Term> = [.my, .your, .his, .her, .our, .their, .its]
    private static let subjectPronouns: Set<Term> = [.me, .you, .he, .she, .it, .we, .they]
    private static let questionWords: Set<Term> = [.what, .who, .when, .where, .why, .how]

    /// Structural checks the `GenerationSchema` cannot express. Guided
    /// generation constrains which tokens appear, never their order, so a
    /// small on-device model can emit a valid-token gloss that is still
    /// nonsense ("FAVORITE WHAT YOUR"). Rejecting here is cheap; the caller
    /// over-requests and falls back to the bank when too few survive.
    static func isStructurallyValid(_ gloss: [Term]) -> Bool {
        guard let last = gloss.last else { return false }

        // "FAVORITE WHAT YOUR" — a possessive with nothing to own.
        if possessives.contains(last) { return false }

        // Pronouns alone carry no content ("ME YOU", "MY YOUR").
        if gloss.allSatisfy({ possessives.contains($0) || subjectPronouns.contains($0) }) {
            return false
        }

        // ASL puts the question word last. "FAVORITE WHAT YOUR" and
        // "WHAT YOUR NAME" both fail here; "YOUR NAME WHAT" passes.
        if gloss.dropLast().contains(where: { questionWords.contains($0) }) { return false }

        // Fingerspelling is one token per letter, so a lone alphabet token is
        // a truncated name ("NAME ME J"). Require letters to appear in runs of
        // at least two.
        if hasOrphanLetter(gloss) { return false }

        return true
    }

    private static func hasOrphanLetter(_ gloss: [Term]) -> Bool {
        for (index, term) in gloss.enumerated() where term.category == .alphabet {
            let precededByLetter = index > 0 && gloss[index - 1].category == .alphabet
            let followedByLetter = index + 1 < gloss.count && gloss[index + 1].category == .alphabet
            if !precededByLetter && !followedByLetter { return true }
        }
        return false
    }

    /// Splits on commas **and** spaces, trims punctuation, and uppercases.
    /// Hyphens are not split, so a hyphenated compound survives as one token.
    static func tokenizeGloss(_ gloss: String) -> [String] {
        gloss
            .split(separator: ",")
            .flatMap { $0.split(separator: " ") }
            .map { token in
                String(token)
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: .punctuationCharacters)
                    .uppercased()
            }
            .filter { !$0.isEmpty }
    }

    /// Maps "I" → "ME" except when it sits adjacent to other alphabet
    /// tokens, i.e. it is a fingerspelled letter (as in "I A N").
    static func normalizeFirstPersonPronouns(in tokens: [String]) -> [String] {
        tokens.enumerated().map { index, token in
            guard token == Term.i.rawValue, !isFingerspelledLetter(at: index, in: tokens) else {
                return token
            }
            return Term.me.rawValue
        }
    }

    private static func isFingerspelledLetter(at index: Int, in tokens: [String]) -> Bool {
        guard tokens.indices.contains(index),
              Term(rawValue: tokens[index])?.category == .alphabet else {
            return false
        }

        let hasAlphabetBefore = tokens.indices.contains(index - 1)
            && Term(rawValue: tokens[index - 1])?.category == .alphabet
        let hasAlphabetAfter = tokens.indices.contains(index + 1)
            && Term(rawValue: tokens[index + 1])?.category == .alphabet

        return hasAlphabetBefore || hasAlphabetAfter || tokens.allSatisfy { Term(rawValue: $0)?.category == .alphabet }
    }
}
