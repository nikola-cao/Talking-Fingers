//
//  validate_sentence_bank.swift
//  Talking Fingers
//
//  Build-time validator for Talking Fingers/Resources/SentenceBank.json.
//  See ON_DEVICE_SENTENCE_GENERATION_PLAN.md §4.6 for the checks this
//  implements.
//
//  This is compiled together with the real Term.swift (rather than
//  hand-copying the vocabulary list), so it can never silently drift from
//  the app's actual vocabulary — if Term.swift changes, this validator sees
//  the change the next time it runs. `@main` (rather than top-level script
//  statements) is what lets this file keep its own name under `swiftc`
//  multi-file compilation instead of having to be named `main.swift`.
//
//  Usage (run from the repo root):
//    swiftc -o /tmp/validate_sentence_bank \
//      Tools/validate_sentence_bank.swift \
//      "Talking Fingers/Flashcards/Models/Term.swift" \
//      && /tmp/validate_sentence_bank
//
//  Optionally pass a bank path as the first argument; it defaults to
//  "Talking Fingers/Resources/SentenceBank.json" relative to the current
//  working directory.
//
//  Exit code is non-zero if any FAIL-level issue is found. WARN-level
//  issues are printed but do not affect the exit code.

import Foundation

// MARK: - Bank file schema

private struct BankFile: Decodable {
    let version: Int
    let sentences: [BankEntry]
}

private struct BankEntry: Decodable {
    let id: String
    let english: String
    let gloss: [String]
    let category: String
}

@main
struct SentenceBankValidator {
    /// Minimum sentences a category needs before it's considered usable.
    private static let minimumEntriesPerCategory = 5

    static func main() {
        let bankPath = CommandLine.arguments.dropFirst().first ?? "Talking Fingers/Resources/SentenceBank.json"

        let bankURL = URL(fileURLWithPath: bankPath)
        guard let data = try? Data(contentsOf: bankURL) else {
            print("FAIL: could not read bank file at \(bankPath)")
            exit(1)
        }

        let bank: BankFile
        do {
            bank = try JSONDecoder().decode(BankFile.self, from: data)
        } catch {
            print("FAIL: could not decode \(bankPath): \(error)")
            exit(1)
        }

        var failures: [String] = []
        var warnings: [String] = []

        // Precompute every hyphenated Term's split parts, so we can detect a
        // compound accidentally being emitted as separate adjacent tokens.
        let hyphenatedCompoundParts: [[String]] = Term.allCases
            .map { $0.rawValue }
            .filter { $0.contains("-") }
            .map { $0.split(separator: "-").map(String.init) }

        var seenIDs: Set<String> = []
        var seenEnglishKeys: Set<String> = []
        var seenGlossKeys: Set<String> = []
        var countsByCategory: [TermCategory: Int] = [:]

        for entry in bank.sentences {
            let context = "[\(entry.id)]"

            if entry.gloss.isEmpty {
                failures.append("\(context) has an empty gloss.")
            }
            let trimmedEnglish = entry.english.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedEnglish.isEmpty {
                failures.append("\(context) has empty/whitespace English text.")
            }

            guard let category = TermCategory(rawValue: entry.category) else {
                failures.append("\(context) has unknown category '\(entry.category)'.")
                continue
            }
            countsByCategory[category, default: 0] += 1

            let expectedPrefix = idSlug(for: category) + "-"
            if !entry.id.hasPrefix(expectedPrefix) {
                failures.append("\(context) id does not start with expected prefix '\(expectedPrefix)' for category '\(entry.category)'.")
            }

            if seenIDs.contains(entry.id) {
                failures.append("\(context) duplicate id.")
            }
            seenIDs.insert(entry.id)

            let resolvedTerms = entry.gloss.compactMap { Term(rawValue: $0) }
            if resolvedTerms.count != entry.gloss.count {
                let unresolved = entry.gloss.filter { Term(rawValue: $0) == nil }
                failures.append("\(context) has unresolvable gloss token(s): \(unresolved.joined(separator: ", ")).")
                continue
            }

            let allowedForEntry = Set(Term.words(for: category) + Term.words(for: .personalInformation))
            let outOfScope = resolvedTerms.filter { !allowedForEntry.contains($0) }
            if !outOfScope.isEmpty {
                let names = outOfScope.map { $0.rawValue }.joined(separator: ", ")
                failures.append("\(context) uses term(s) outside its own category ∪ personalInformation: \(names).")
            }

            for parts in hyphenatedCompoundParts where parts.count > 1 {
                var index = 0
                while index + parts.count <= entry.gloss.count {
                    if Array(entry.gloss[index..<(index + parts.count)]) == parts {
                        failures.append("\(context) splits hyphenated compound '\(parts.joined(separator: "-"))' into separate tokens \(parts.joined(separator: " ")).")
                        break
                    }
                    index += 1
                }
            }

            let englishKey = trimmedEnglish.lowercased()
            let glossKey = entry.gloss.joined(separator: " ")
            if seenEnglishKeys.contains(englishKey) {
                failures.append("\(context) duplicates English text of an earlier entry: \"\(trimmedEnglish)\".")
            }
            if seenGlossKeys.contains(glossKey) {
                failures.append("\(context) duplicates gloss sequence of an earlier entry: \(glossKey).")
            }
            seenEnglishKeys.insert(englishKey)
            seenGlossKeys.insert(glossKey)

            for (index, term) in resolvedTerms.enumerated() where term == .me {
                guard resolvedTerms.indices.contains(index + 1) else { continue }
                let next = resolvedTerms[index + 1]
                if isLikelyOwnedNoun(next) {
                    warnings.append("\(context) has \"ME \(next.rawValue)\" — did you mean \"MY \(next.rawValue)\"?")
                }
            }
        }

        for category in countsByCategory.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let count = countsByCategory[category] ?? 0
            if count < minimumEntriesPerCategory {
                failures.append("Category '\(category.rawValue)' has only \(count) entries (minimum \(minimumEntriesPerCategory)).")
            }
        }

        print("Checked \(bank.sentences.count) entries across \(countsByCategory.count) categories.")
        for category in countsByCategory.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            print("  \(category.rawValue): \(countsByCategory[category] ?? 0)")
        }

        if !warnings.isEmpty {
            print("\nWARNINGS:")
            warnings.forEach { print("  ⚠️  \($0)") }
        }

        if !failures.isEmpty {
            print("\nFAILURES:")
            failures.forEach { print("  ✘ \($0)") }
            print("\n\(failures.count) failure(s).")
            exit(1)
        }

        print("\nAll checks passed.")
    }

    /// Terms that read as a likely mistake when "ME" (rather than "MY")
    /// immediately precedes them — an owned noun. Heuristic warning only.
    private static func isLikelyOwnedNoun(_ term: Term) -> Bool {
        if term.category == .family || term.category == .locations { return true }
        return term == .name || term == .work || term == .favorite || term == .age
    }

    /// Maps a category to the ID prefix its bank entries must use.
    private static func idSlug(for category: TermCategory) -> String {
        category.rawValue
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: [.regularExpression])
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
