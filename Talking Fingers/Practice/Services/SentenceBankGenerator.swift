//
//  SentenceBankGenerator.swift
//  Talking Fingers
//
//  The universal fallback sentence source (plan §4) — pre-authored,
//  pre-validated sentences bundled with the app. Requires no network access
//  and no on-device model, so it always works, including on hardware that
//  can't run Foundation Models at all.
//

import Foundation

final class SentenceBankGenerator: SentenceGenerating {
    static let shared = SentenceBankGenerator()

    private struct BankEntry {
        let id: String
        let english: String
        let gloss: [Term]
        let category: TermCategory
    }

    private static let recentlyServedDefaultsKey = "SentenceBankGenerator.recentlyServedIDs"
    /// How many multiples of a single request's `count` to remember before
    /// letting an ID be served again (plan §4.4).
    private static let recentHistoryMultiplier = 3

    private let entries: [BankEntry]

    init(bundle: Bundle = .main) {
        entries = Self.loadEntries(from: bundle)
    }

    private static func loadEntries(from bundle: Bundle) -> [BankEntry] {
        guard let url = bundle.url(forResource: "SentenceBank", withExtension: "json") else {
            assertionFailure("SentenceBank.json is missing from the app bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(SentenceBankFile.self, from: data)
            return file.sentences.compactMap { raw in
                guard let category = TermCategory(rawValue: raw.category) else {
                    assertionFailure("SentenceBank.json entry \(raw.id) has unknown category '\(raw.category)'.")
                    return nil
                }
                let terms = raw.gloss.compactMap { Term(rawValue: $0) }
                guard terms.count == raw.gloss.count else {
                    assertionFailure("SentenceBank.json entry \(raw.id) has an unresolvable gloss token — bank and Term.swift have drifted.")
                    return nil
                }
                return BankEntry(id: raw.id, english: raw.english, gloss: terms, category: category)
            }
        } catch {
            assertionFailure("Failed to decode SentenceBank.json: \(error)")
            return []
        }
    }

    func generateSentences(
        allowedTerms: Set<Term>,
        focusTerms: [Term],
        learningState: LearningStateSummary,
        count: Int
    ) async throws -> [AISentenceModel] {
        // A sentence is eligible exactly when its owning category is one the
        // request covers. `focusTerms` already IS "terms in the eligible
        // categories" (VocabularyScope), so mapping back to categories
        // recovers that set.
        //
        // `.personalInformation` is deliberately NOT unioned in here, even
        // though `allowedTerms` unions it. Those are different questions:
        // allowedTerms controls which vocabulary may appear INSIDE a sentence
        // (a family sentence needs MY, ME, LIKE), while this controls which
        // sentences are eligible at all. Unioning it here made PI-owned
        // sentences ~45% of a single-category request — "ME STUDENT" in a
        // family session, containing no family vocabulary. Family-owned
        // entries already carry PI vocabulary by construction, so nothing is
        // lost. PI-owned sentences surface when personal information is itself
        // an eligible category.
        let eligibleCategories = Set(focusTerms.map(\.category))

        let candidates = entries.filter { eligibleCategories.contains($0.category) }
        guard !candidates.isEmpty else { return [] }

        let recentlyServed = loadRecentlyServedIDs()

        // Reset the exclusion set when it would leave too few candidates,
        // rather than starving the request over stale history.
        let freshCandidates = candidates.filter { !recentlyServed.contains($0.id) }
        let pool = freshCandidates.count >= count ? freshCandidates : candidates

        // Every eligible sentence is equally likely. No relevance or
        // familiarity weighting: category-level scoping already keeps the
        // vocabulary in range, and any per-sentence score risks the bias that
        // made a match-count ranking degenerate into "longest gloss wins"
        // (alphabet entries, at ~6 tokens to verbs' ~2.6, took every slot).
        let selected = Array(pool.shuffled().prefix(count))

        recordServed(ids: selected.map(\.id), requestedCount: count)

        return selected.map { entry in
            AISentenceModel(
                sentence: entry.english,
                score: nil,
                practiceType: .words,
                gloss: entry.gloss,
                completed: false
            )
        }
    }

    private func loadRecentlyServedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.recentlyServedDefaultsKey) ?? [])
    }

    private func recordServed(ids: [String], requestedCount: Int) {
        guard !ids.isEmpty else { return }
        var history = UserDefaults.standard.stringArray(forKey: Self.recentlyServedDefaultsKey) ?? []
        history.append(contentsOf: ids)

        let cap = requestedCount * Self.recentHistoryMultiplier
        if history.count > cap {
            history.removeFirst(history.count - cap)
        }
        UserDefaults.standard.set(history, forKey: Self.recentlyServedDefaultsKey)
    }
}

private struct SentenceBankFile: Codable {
    let version: Int
    let sentences: [SentenceBankRawEntry]
}

private struct SentenceBankRawEntry: Codable {
    let id: String
    let english: String
    let gloss: [String]
    let category: String
}
