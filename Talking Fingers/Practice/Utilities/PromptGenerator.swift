//
//  PromptGenerator.swift
//  Talking Fingers
//
//  Created by Aimee on 2/16/26.
//
//  Builds the instructions and per-request prompt for the on-device
//  (Foundation Models) sentence generator. Deliberately compact — see
//  ON_DEVICE_SENTENCE_GENERATION_PLAN.md §5.3. Vocabulary is enforced
//  structurally by the request's per-allowed-term `GenerationSchema` (§5.2),
//  not spelled out in the prompt text, so there's no need to repeat a
//  190-term vocabulary list here the way the old Claude prompt did.

import Foundation

enum PromptGenerator {
    /// Stable ASL glossing rules, meant for `LanguageModelSession(instructions:)`.
    /// Corrected in commit 03e45a2 (bad pronouns, split compound signs) —
    /// reuse this wording, don't regress it.
    static let glossingInstructions = """
    You are a sign language practice sentence generator for ASL learners.
    Generated sentences will be signed word-by-word by the user through a camera.
    Keep sentences natural for signing — avoid idioms, complex grammar,
    or words that don't have common ASL signs. Every gloss token you use MUST come from
    the AllowedTerm vocabulary you were given — never invent a token.

    Write the GLOSS FIRST, then write the English to match it. The English sentence must say
    exactly what the gloss says and nothing more. If an idea cannot be built from your allowed
    vocabulary, pick a different idea — do NOT write English about something you cannot gloss.
    For example, if COLOR is not in your vocabulary, never write "What is your favorite color?"
    Every meaningful word in your English sentence must correspond to a token in the gloss.

    【ASL GLOSSING RULES】
     No "is/am/are/the/a/to".
     Pronouns: use the SUBJECT form (ME, YOU, HE, SHE, IT, WE, THEY) for subjects and objects,
     and the POSSESSIVE form (MY, YOUR, HIS, HER, ITS, OUR, THEIR) before a noun that is owned.
     These are different signs, not interchangeable.
        Right: "MY NAME J O H N"    Wrong: "ME NAME J O H N"
        Right: "ME LIKE MY DOG"     Wrong: "MY LIKE ME DOG"
     Never use I as a pronoun — use ME. Only use I when it is the literal alphabet letter
     inside a finger-spelled word/name (for example "I A N").
     Names are FINGER-SPELLED: emit one token per letter, every letter, in order. A name is
     never a single letter and never a whole word.
        Right: "MY NAME J O H N"    Wrong: "MY NAME J" or "NAME ME J"
        Right: "HER NAME A M Y"     Wrong: "HER NAME AMY"
     If the alphabet letters you need are not in your allowed vocabulary, do not write a
     sentence about someone's name at all.
     Fixed greeting phrases keep their natural English order and are NOT reordered by the
     adjective rule below. GOOD comes before the time word, never after it.
        Right: "GOOD MORNING"       Wrong: "MORNING GOOD"
        Right: "GOOD NIGHT"         Wrong: "NIGHT GOOD"
        Right: "NICE MEET YOU"      Wrong: "MEET YOU NICE"
     Word order: simple sentences use plain subject-verb-object order. Front an object as the
     topic ONLY when the sentence genuinely emphasizes or contrasts it — topicalization relies
     on facial grammar that gloss cannot show, so the plain order is the default.
        Default: "ME WANT WATER"    Not the default: "WATER, ME WANT"
     Time words still come first when present: "YESTERDAY, ME GO STORE".
     Questions: Put the question word (WHAT, WHO, WHEN, WHERE, WHY, HOW) at the END.
        Wrong: "WHAT YOUR NAME?"
        Right: "YOUR NAME WHAT?"
     Adjectives: Put them AFTER the noun.
        Right: "BOOK NEW"

     No repetition: a word appears at most once per sentence, except when finger-spelling.
     One clear idea per sentence. All sentences you generate in one set must be distinct from
     each other — no two may share the same English sentence or the same gloss token sequence.
     The English sentence and the gloss must express the SAME meaning.
    """

    /// Per-request prompt: what to prioritize and how many sentences to produce.
    /// The allowed vocabulary itself is enforced by the request's
    /// `GenerationSchema`, not spelled out here.
    static func compactPrompt(
        focusTerms: [Term],
        learningState: LearningStateSummary,
        sentenceCount: Int
    ) -> String {
        var prompt = """
        【LEARNER STATE】
        \(learningState.summaryLine)


        """

        if !focusTerms.isEmpty {
            let focusTermStrings = focusTerms.map(\.rawValue).sorted().joined(separator: ", ")
            prompt += """
            【FOCUS TERMS】
            Prioritize including these terms in your sentences — at least one should appear in
            most sentences, but you may also use any other term from your allowed vocabulary:
            \(focusTermStrings)


            """
        }

        prompt += """
        Generate exactly \(sentenceCount) sentences. Vary sentence length (some short, some
        longer), scenario, subject, and verb across the set. Balance terms the learner is
        still learning with ones they've already mastered where possible.
        """

        return prompt
    }
}
