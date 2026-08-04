//
//  FoundationModelsGenerator.swift
//  Talking Fingers
//
//  On-device sentence generation via Apple's Foundation Models framework
//  (iPhone 15 Pro+, Apple-silicon Mac, M1+ iPad — see plan §5). Builds a
//  `GenerationSchema` per request from `allowedTerms` so the decoder cannot
//  emit a term outside the learner's selection — the vocabulary constraint
//  is enforced structurally, not just by the prompt.
//
//  Any failure (unavailable model, guardrail refusal, decoding failure,
//  context overflow) falls through to an empty result; the caller
//  (`SentenceGenerationService`) is responsible for falling back to
//  `SentenceBankGenerator` when that happens.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsGenerator: SentenceGenerating {
    /// Upper bound on tokens in a single gloss — generous enough for the
    /// longest fingerspelled-name sentences in the seed bank.
    private static let maxGlossTokens = 12

    func generateSentences(
        allowedTerms: Set<Term>,
        focusTerms: [Term],
        learningState: LearningStateSummary,
        count: Int
    ) async throws -> [AISentenceModel] {
        guard case .available = SystemLanguageModel.default.availability, !allowedTerms.isEmpty else {
            return []
        }

        let schema: GenerationSchema
        do {
            schema = try Self.buildSchema(allowedTerms: allowedTerms, count: count)
        } catch {
            // A malformed dynamic schema should never reach production, but
            // if it does, degrade to the bank rather than crash.
            return []
        }

        let prompt = PromptGenerator.compactPrompt(
            focusTerms: focusTerms,
            learningState: learningState,
            sentenceCount: count
        )

        let session = LanguageModelSession(instructions: PromptGenerator.glossingInstructions)

        let response: LanguageModelSession.Response<GeneratedContent>
        do {
            response = try await session.respond(
                to: prompt,
                schema: schema,
                includeSchemaInPrompt: true
            )
        } catch {
            // Guardrail refusal, exceeded context window, decoding failure, etc.
            return []
        }

        guard let sentenceContents = try? response.content.value([GeneratedContent].self, forProperty: "sentences") else {
            return []
        }

        let rawPairs: [(english: String?, gloss: String)] = sentenceContents.compactMap { item in
            guard
                let english = try? item.value(String.self, forProperty: "english"),
                let glossTokens = try? item.value([String].self, forProperty: "gloss"),
                !glossTokens.isEmpty
            else { return nil }
            return (english: english, gloss: glossTokens.joined(separator: " "))
        }

        // Guided generation guarantees valid tokens, not good sentences — a
        // small on-device model can still repeat itself or say "ME NAME"
        // instead of "MY NAME". Run the same validator every backend uses.
        return SentenceValidation.convertToAISentences(
            rawPairs,
            allowedTerms: allowedTerms,
            targetCount: count
        )
    }

    /// Builds a per-request schema so the model can only emit tokens from
    /// `allowedTerms` — a per-request enum of ~40-60 permitted terms rather
    /// than a static 190-case one, and it enforces the learner's category
    /// scoping structurally (plan §5.2).
    private static func buildSchema(allowedTerms: Set<Term>, count: Int) throws -> GenerationSchema {
        let termNames = allowedTerms.map(\.rawValue).sorted()

        let termSchema = DynamicGenerationSchema(
            name: "AllowedTerm",
            description: "A single ASL vocabulary token the learner has access to.",
            anyOf: termNames
        )

        let glossSchema = DynamicGenerationSchema(
            arrayOf: DynamicGenerationSchema(referenceTo: "AllowedTerm"),
            minimumElements: 1,
            maximumElements: maxGlossTokens
        )

        let sentenceItemSchema = DynamicGenerationSchema(
            name: "GeneratedSentence",
            description: "One practice sentence: a natural English sentence plus its ASL gloss.",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "english",
                    description: "A natural, grammatical English sentence.",
                    schema: DynamicGenerationSchema(type: String.self)
                ),
                DynamicGenerationSchema.Property(
                    name: "gloss",
                    description: "The ASL gloss word order, using only AllowedTerm tokens.",
                    schema: glossSchema
                )
            ]
        )

        let sentencesArraySchema = DynamicGenerationSchema(
            arrayOf: DynamicGenerationSchema(referenceTo: "GeneratedSentence"),
            minimumElements: count,
            maximumElements: count
        )

        let rootSchema = DynamicGenerationSchema(
            name: "GeneratedSentenceSet",
            description: "A set of ASL practice sentences.",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "sentences",
                    description: "The generated sentences.",
                    schema: sentencesArraySchema
                )
            ]
        )

        return try GenerationSchema(root: rootSchema, dependencies: [termSchema, sentenceItemSchema])
    }
}
