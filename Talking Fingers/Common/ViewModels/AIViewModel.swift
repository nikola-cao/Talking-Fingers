//
//  AIViewModel.swift
//  Talking Fingers
//
//  Created by Krish Prasad on 2/15/26.
//

import Foundation
import Observation
import FirebaseFirestore

@Observable class AIViewModel {
    var apiKey: String?
    private var db: Firestore { Firebase.db }
    private let anthropicURL = "https://api.anthropic.com/v1/messages"
    private let anthropicVersion = "2023-06-01"
    private let model = "claude-opus-5"
    /// Generous headroom: max_tokens caps thinking + response text together,
    /// and thinking is on by default on this model.
    private let maxTokens = 8000
    private let requestedSentenceCount = 7
    private let targetValidSentenceCount = 5
    
    /// Shared instance that persists across the app lifecycle.
    /// Using a shared instance avoids repeated Firestore fetches and cold-start delays.
    static let shared = AIViewModel()
    
    init()  {
        fetchAPIKey()
    }
    
    private func fetchAPIKey() {
        Task {
            do {
                let document = try await db.collection("API_KEYS").document("Anthropic").getDocument()
                if let data = document.data(), let key = data["key"] as? String {
                    await MainActor.run {
                        self.apiKey = key
                        print("key found")
                    }
                } else {
                    print("No key found in document")
                }
            } catch {
                print("Error fetching API key from Firestore: \(error)")
            }
        }
    }
    
    /// Waits for the API key to be available, with a timeout.
    /// - Parameter timeout: Maximum time to wait in seconds (default 10 seconds)
    /// - Throws: `AIError.missingAPIKey` if the key isn't available within the timeout
    func waitForAPIKey(timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        while apiKey == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: pollInterval)
        }

        guard apiKey != nil else {
            throw AIError.missingAPIKey
        }
    }

    func generateAISentences(from flashcards: [FlashcardModel], focusTerms: [Term] = []) async throws -> [AISentenceModel] {
        guard let apiKey else {
            throw AIError.missingAPIKey
        }
        
        let prompt = generatePrompt(from: flashcards, focusTerms: focusTerms)
        let sentencesResponse = try await requestSentences(prompt: prompt, apiKey: apiKey)
        return convertToAISentences(sentencesResponse)
    }

    private func generatePrompt(from flashcards: [FlashcardModel], focusTerms: [Term]) -> String {
        return PromptGenerator.generatePromptForLLM(
            from: flashcards,
            focusTerms: focusTerms,
            sentenceCount: requestedSentenceCount
        )
    }
    
    /// JSON Schema the model's response is constrained to. Every object needs
    /// `required` plus `additionalProperties: false` for structured outputs.
    private var sentenceSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "sentences": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "english": [
                                "type": "string",
                                "description": "A natural, readable English sentence."
                            ],
                            "sentence": [
                                "type": "string",
                                "description": "The ASL gloss, using only allowed vocabulary."
                            ]
                        ],
                        "required": ["english", "sentence"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["sentences"],
            "additionalProperties": false
        ]
    }

    private func requestSentences(prompt: String, apiKey: String) async throws -> [SentenceData] {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": "You are an ASL education assistant. For each sentence return two parts: \"english\" (a natural, readable English sentence) and \"sentence\" (the ASL gloss using only allowed vocabulary). Vary phrasing, sentence length, and scenario across the set so repeated generations don't repeat themselves.",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": sentenceSchema
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIError.invalidRequest
        }

        var request = URLRequest(url: URL(string: anthropicURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError
        }

        guard httpResponse.statusCode == 200 else {
            print("Anthropic API Error - Status Code: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error response: \(errorString)")
            }
            throw AIError.apiError
        }

        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        // A refusal or a truncated response won't satisfy the schema — fail
        // loudly rather than handing back a half-parsed sentence list.
        if anthropicResponse.stopReason == "refusal" {
            print("Request was refused: \(anthropicResponse.stopDetails?.explanation ?? "no explanation")")
            throw AIError.refused
        }
        if anthropicResponse.stopReason == "max_tokens" {
            print("Response hit max_tokens (\(maxTokens)) and was truncated.")
            throw AIError.emptyResponse
        }

        // `content` is a list of blocks; thinking blocks precede the text block.
        guard let content = anthropicResponse.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.emptyResponse
        }

        guard let contentData = content.data(using: .utf8) else {
            throw AIError.decodingError
        }

        do {
            let wrapper = try JSONDecoder().decode(SentencesWrapper.self, from: contentData)
            return wrapper.sentences
        } catch {
            print("❌ DECODING ERROR:")
            print("Raw content from Claude:")
            print(content)
            print("Decoding error: \(error)")
            throw AIError.decodingError
        }
    }
    
    private func convertToAISentences(_ sentencesResponse: [SentenceData]) -> [AISentenceModel] {
        let allowedTokenSet = Set(Term.allCases.map(\.rawValue))
        var aiSentences: [AISentenceModel] = []
        var seenEnglishKeys: Set<String> = []
        var seenGlossKeys: Set<String> = []

        for sentenceData in sentencesResponse {
            let glossWordStrings = normalizeFirstPersonPronouns(in: tokenizeGloss(sentenceData.sentence))
            guard !glossWordStrings.isEmpty else { continue }
            guard glossWordStrings.allSatisfy({ allowedTokenSet.contains($0) }) else { continue }
            
            let glossTerms = Term.fromStrings(glossWordStrings)
            guard glossTerms.count == glossWordStrings.count else { continue }
            
            let displaySentence = sentenceData.english ?? sentenceData.sentence

            // Drop duplicates coming back from the model (same English text or
            // same gloss sequence). Without this, a narrow focus-term prompt
            // can cause back-to-back identical practice sentences.
            let englishKey = displaySentence
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let glossKey = glossTerms.map(\.rawValue).joined(separator: " ")
            if seenEnglishKeys.contains(englishKey) || seenGlossKeys.contains(glossKey) {
                print("⚠️ Dropping duplicate AI sentence: \(displaySentence)")
                continue
            }
            seenEnglishKeys.insert(englishKey)
            seenGlossKeys.insert(glossKey)

            let aiSentence = AISentenceModel(
                sentence: displaySentence,
                score: nil,
                practiceType: .words,
                gloss: glossTerms,
                completed: false
            )
            
            aiSentences.append(aiSentence)
            
            if aiSentences.count == targetValidSentenceCount {
                break
            }
        }
        
        return aiSentences
    }
    
    private func tokenizeGloss(_ gloss: String) -> [String] {
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

    private func normalizeFirstPersonPronouns(in tokens: [String]) -> [String] {
        tokens.enumerated().map { index, token in
            guard token == Term.i.rawValue, !isFingerspelledLetter(at: index, in: tokens) else {
                return token
            }
            return Term.me.rawValue
        }
    }

    private func isFingerspelledLetter(at index: Int, in tokens: [String]) -> Bool {
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

// MARK: - Response Models

private struct AnthropicResponse: Codable {
    let content: [ContentBlock]
    let stopReason: String?
    let stopDetails: StopDetails?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }

    struct ContentBlock: Codable {
        let type: String
        /// Only present on `text` blocks.
        let text: String?
    }

    /// Populated only when `stopReason == "refusal"`.
    struct StopDetails: Codable {
        let category: String?
        let explanation: String?
    }
}

private struct SentencesWrapper: Codable {
    let sentences: [SentenceData]
}

private struct SentenceData: Codable {
    /// Plain English sentence (for display). If missing, fall back to gloss string.
    let english: String?
    /// ASL gloss word order (for signing); only words from vocabulary list.
    let sentence: String
}

// MARK: - Errors

enum AIError: Error {
    case missingAPIKey
    case invalidRequest
    case apiError
    case emptyResponse
    case decodingError
    case refused
}
