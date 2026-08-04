# Plan: On-Device Sentence Generation

> ## Status — read this first
>
> **Shipped (commit `7c9212a`): the sentence bank.** 2,115 pre-authored sentences,
> category-scoped vocabulary, real flashcard progress, no network call. This is the
> live path on every device.
>
> **Parked: Foundation Models.** `FoundationModelsGenerator` is still in the tree and
> still compiles, but it is **off by default** behind a `DEBUG` override. Evaluation on
> an M3 Pro found the on-device model unable to produce reliable ASL gloss — see
> **§9 Evaluation** for the evidence, the root cause, and what would have to change
> before revisiting it.
>
> If you are picking this up later, read §9 first. It supersedes the optimism in §5.

**Original goal:** Replace the Claude API call for practice-sentence generation with a
free, offline path — Apple's Foundation Models framework where the hardware supports it,
and a pre-generated sentence bank everywhere else. At the same time, restrict generated
vocabulary to what the learner actually selected or has actually learned.

**Why:** There is no Anthropic API billing budget. The old implementation returned
`400 invalid_request_error` ("credit balance is too low") on every request, so sentence
generation was completely non-functional.

---

## 1. Background — read this before writing code

### 1.1 What the feature does

A learner selects practice categories. The app builds a prompt describing their
flashcard progress and the selected focus terms, asks an LLM for practice sentences,
and returns `[AISentenceModel]`. Each sentence has two halves:

- `sentence` (String) — natural English, shown to the learner to read.
- `gloss` (`[Term]`) — ASL gloss word order, which the learner signs into the camera
  one token at a time.

Both halves must express the same meaning, and **every gloss token must be a member of
the allowed vocabulary for that request** (see §2) or the app cannot show a sign for it.

### 1.2 Call path (as shipped)

```
PracticeEntryView / GenerateSentencesView
  └─ SentenceGenerationService.generateSentences(categories:flashcards:modeSelection:)
       ├─ VocabularyScope.resolve(...)          → eligibleCategories + allowedTerms (§2)
       ├─ LearningStateSummary(...)             → compact progress summary
       └─ generateWithFallback(...)
            └─ SentenceBankGenerator.shared     → bundled SentenceBank.json
               (FoundationModelsGenerator only via DEBUG override — §9)
```

`AIViewModel` — the old Firestore-key-fetching Claude client — has been **deleted**.

The bank asks for exactly `targetValidSentenceCount` (5). Only the Foundation Models
path over-requests (`modelOverRequestCount` = 10), because only it discards output.
**Do not raise the bank's request count**: `SentenceBankGenerator.recordServed` marks
every returned ID as recently-served, so requesting more than is shown silently burns
unseen sentences out of the rotation.

### 1.3 `SentenceValidation` — the shared validation layer

Moved out of the old `AIViewModel` into
`Talking Fingers/Practice/Utilities/SentenceValidation.swift` so any backend can reuse it.
The bank does **not** run through it — bank entries are pre-validated at author time by
`Tools/validate_sentence_bank.swift`. It:

1. Tokenizes the gloss string by splitting on commas **and** spaces, trimming
   punctuation, and uppercasing. Hyphens are not split (harmless now that no term
   contains one — see §1.4).
2. Rejects any sentence containing a token outside the request's `allowedTerms`.
3. Applies the four structural rules in §9.5 (dangling possessive, pronouns-only,
   misplaced question word, orphan letter).
4. Runs `normalizeFirstPersonPronouns`, mapping `I` → `ME` except when `I` sits adjacent
   to other alphabet tokens (i.e. it is a fingerspelled letter, as in `I A N`).
5. Deduplicates on both the English text and the gloss token sequence.
6. Stops once the target count is collected.

### 1.4 Vocabulary quirks that matter

`Term` is a `String`-backed enum in `Talking Fingers/Flashcards/Models/Term.swift` with
**173 live cases** across 11 `TermCategory` values.

> ⚠️ **Do not extract the vocabulary with a plain grep.** `Term.swift` contains large
> blocks of commented-out cases, and a naive `grep 'case .* = "'` matches them, reporting
> terms that do not exist. It also *misses* backticked Swift-keyword cases. Both errors
> happened during this work and one shipped a bug. Extract by stripping comments first
> and allowing backticks — see the parser at the top of `Tools/generate_sentence_bank.py`,
> or compile against the real enum the way `Tools/validate_sentence_bank.swift` does.

- **There are no hyphenated terms.** All the compound greetings — `GOOD-MORNING`,
  `GOOD-AFTERNOON`, `GOOD-NIGHT`, `SEE-YOU-LATER`, `NICE-MEET-YOU`, `HOW-YOU`, `WHAT-UP`,
  `DON'T-LIKE` — are **commented out** in `Term.swift`. No live raw value contains a
  hyphen. Greetings are built from separate tokens: `GOOD` + `MORNING`.
  - Consequence: the "adjectives go after the noun" rule pushes the model toward
    `MORNING GOOD`. `PromptGenerator` carries an explicit exception for fixed greeting
    phrases (`GOOD MORNING`, never `MORNING GOOD`). Keep it.
  - If the compound terms are ever uncommented, that exception should be revisited and
    the bank regenerated.
- **`WHERE` and `CLASS` are live**, written as backticked keyword cases
  (`` case `where` = "WHERE" ``). Easy to miss when scanning.
- **Subject and possessive pronouns are distinct signs**: `ME`/`MY`, `YOU`/`YOUR`,
  `HE`/`HIS`, `SHE`/`HER`, `IT`/`ITS`, `WE`/`OUR`, `THEY`/`THEIR`. `MY NAME` is correct;
  `ME NAME` is not.
- There is no `APPLE`, `BUY`, `FRIEND`, or `RED`, despite older prompt examples having
  used them. A model asked for "meet your friend" will substitute something wrong.
- **Fingerspelling is one token per letter**: `MY NAME J O H N`, never `MY NAME JOHN` or
  a single initial.

The prompt in `PromptGenerator.swift` was corrected for all of the above (commits
`03e45a2` and `7c9212a`). Reuse that wording; do not regress it.

### 1.5 Constraints

| Constraint | Value |
|---|---|
| iOS deployment target | **26.0** |
| macOS deployment target | 26.0 |
| Toolchain | Xcode 26.6, iOS 26.5 SDK, macOS 26.5 SDK — **verified present** |
| Foundation Models hardware | iPhone 15 Pro or newer; Apple-silicon Mac; M1+ iPad |
| Foundation Models context window | ~4096 tokens |
| API budget | None. Do not add any paid network call. |

**Critical:** iOS 26 runs on iPhone 11 and newer, but Apple Intelligence requires
iPhone 15 Pro or later. A large share of users on a supported OS will still get
`.deviceNotEligible`. The sentence bank is the primary path, not an edge case.

---

## 2. Vocabulary scoping — NEW REQUIREMENT

Sentences must only use words the learner selected or has already learned. This is a
behaviour change: today `PromptGenerator` sets `allowedTerms = Term.allCases` and merely
asks the model to *prioritize* focus terms.

### 2.1 The rule — scope at CATEGORY granularity, not per term

```
eligibleCategories =
    if chosenCategories is non-empty:
        chosenCategories ∩ SentenceGenerationService.allowedCategories
    else:
        every category containing at least one term with progress != .new

allowedTerms = terms(in: eligibleCategories) ∪ terms(in: .personalInformation)
```

**Why category granularity rather than an exact per-term subset.** Terms only leave
`.new` through category practice, so "category studied" is already a strong proxy for
"terms known" — and it degrades gracefully where exact term-matching does not. A learner
two terms into `family` draws from the whole `family` bank instead of almost nothing.

An earlier draft of this plan gated on an exact per-term subset
(`Set(gloss).isSubset(of: learnedTerms)`). **That approach was rejected.** It made most
of a category's bank ineligible for anyone early in that category, which in turn forced a
chain of empty-pool fallbacks. Category-level selection removes that whole class of
problem. Do not reintroduce the per-term gate.

The consequence, accepted deliberately: a sentence may contain a term from a category the
learner is studying but has not personally reached yet. This is treated as incidental
vocabulary exposure, and `SignHintSheetView` already covers a sign they don't know. §2.3
softens it.

### 2.2 "Learned" means past `.new` — and this deliberately differs from the profile stat

For generation, a term counts as learned when its `ProgressType` is `.learning`,
`.polishing`, or `.mastered` — anything but `.new`.
(`ProgressType` is in `Talking Fingers/Flashcards/Utilities/ProgressType.swift`.)

> ⚠️ **Known, intentional inconsistency.** `SwiftDataVM.wordsLearnedCount()` (line 182)
> counts only `.mastered`, and that is what the profile stat shows the user. So the app
> may report "12 words learned" while the generator draws on 80. This was raised and the
> wider pool was chosen deliberately for generation. **Do not "fix" this by unifying the
> two without asking** — changing `wordsLearnedCount()` alters a user-visible number and
> would inflate existing learners' stats overnight.

### 2.3 ~~Term-level knowledge is a ranking preference~~ — removed

An earlier draft ranked sentences whose terms the learner had all seen above ones
introducing an unseen term. **This was removed in favour of equal chance across every
eligible sentence.**

Why: per-sentence scoring kept introducing bias that was hard to see. A relevance score
counting focus-term matches silently became "longest gloss wins" — alphabet entries
average ~6 tokens against verbs' ~2.6, because fingerspelling is one token per letter, so
they took every slot in a no-category request. Category-level scoping (§2.1) already
keeps vocabulary in range, which is what the familiarity sort was really approximating.

Selection is now a uniform random draw from the eligible pool, minus recently-served
(§4.3). If a difficulty curve is wanted later, prefer expressing it through *which
categories are selectable* — see §2.4 — rather than reintroducing a per-sentence score.

### 2.4 `.personalInformation` is always unioned into `allowedTerms` — but NOT into bank eligibility

Two different questions, easy to conflate (and conflated in an earlier draft):

- **`allowedTerms`** — which vocabulary may appear *inside* a sentence. Personal
  information is **always** unioned in here.
- **Bank eligibility** — which sentences may be *drawn*. Personal information is **not**
  added here; only categories the request actually covers are. See §4.2.

Unioning it into eligibility made PI-owned sentences ~45% of a single-category request —
`ME STUDENT` served during a family session, containing no family vocabulary. Family-owned
entries already carry PI vocabulary by construction (`MY MOTHER STUDENT`), so excluding
the PI *pool* costs nothing.

> **Planned (not yet implemented):** categories the learner hasn't studied will not be
> selectable, and **personal information is a prerequisite for every other category**.
> That makes the exclusion above straightforwardly correct — by the time `family` is
> selectable, PI vocabulary is already known, so PI-only sentences teach nothing new.
> It also means §2.5's day-one fallback should probably become `.personalInformation`
> rather than `.greetings`; revisit when the gating lands.

The union into `allowedTerms` is not a convenience — it is required for grammaticality.
Verified against the actual term lists:

| Category picked alone | Contents | Can form a sentence? |
|---|---|---|
| family | all nouns (`MOTHER`, `FATHER`, `SISTER`…) | **No** — no pronouns, no verbs |
| locations | all nouns (`HOME`, `SCHOOL`, `STORE`…) | **No** — same |
| verbs | all verbs (`GO`, `EAT`, `WANT`…) | **No** — no subject |
| personal information | pronouns, question words, `LIKE`/`GO`/`LIVE`/`WORK` | Yes |

`.personalInformation` holds every pronoun pair and the question words, so unioning it
makes `family` yield `ME LIKE MY SISTER` instead of nothing.

### 2.5 Zero-progress fallback

A day-one learner has no non-`.new` terms anywhere, so `eligibleCategories` is empty.
Handle explicitly: fall back to `.greetings` as the starter category (plus the usual
`.personalInformation` union). This is the *only* fallback needed — §2.1 removed the rest.

### 2.6 Progress data is not currently reaching the generator — fix this first

`SentenceGenerationService.swift:52-59` fabricates its flashcards:

```swift
FlashcardModel(term: term, id: UUID(), category: term.category, gifFileName: nil)
```

No `progress` argument, so it defaults to `.new`; `lastSucceeded` is `nil` and `starred`
is `false`. **Every card handed to `PromptGenerator` is synthetic.** Consequences:

- `analyzeLearningState` has always reported `profile:BEGINNER`, `recent_success:0`,
  and 100% new cards, for every learner.
- The prompt rule *"each sentence should have at least 1-2 words the user is still
  learning"* has never had real data to act on.
- The `.new`-based "learned" filter in §2.1 cannot work until this is fixed.

Real progress lives in SwiftData — see `SwiftDataVM.swift:26` for the
`FetchDescriptor<FlashcardModel>` pattern, synced to Firestore under
`Users/{uid}/cardProgress/{term}` (`FlashcardsServices.swift:41`).

**Required change:** `SentenceGenerationService.generateSentences` must accept a real
flashcard source rather than fabricating one. Either pass `[FlashcardModel]` in, or pass
a `ModelContext`/repository and fetch inside. Both call sites (New Practice sheet and
Extend-in-session) need updating. Prefer passing the fetched array in — it keeps the
service testable and free of SwiftData coupling.

### 2.7 Where the constraint is enforced

Defence in depth — `allowedTerms` (§2.1) must be applied at all three layers:

1. **Prompt / schema** — only the allowed terms are offered to the model (§5.2).
2. **Bank query** — only banks for eligible categories are drawn from (§4.2).
3. **Validation** — `convertToAISentences` checks membership in `allowedTerms`, not
   `Term.allCases` (§1.3, step 2).

---

## 3. Target architecture

```
SentenceGenerationService
  ├─ computes `allowed: Set<Term>` per §2.1
  └─ resolves a SentenceGenerating implementation
       ├─ FoundationModelsGenerator   (iPhone 15 Pro+, Apple Intelligence on)
       └─ SentenceBankGenerator       (everything else — always works)
```

### 3.1 The protocol

New file: `Talking Fingers/Practice/Services/SentenceGenerating.swift`

```swift
protocol SentenceGenerating {
    /// Produces practice sentences whose gloss tokens are all members of `allowedTerms`.
    /// - Returns: up to `count` sentences; may return fewer, never invalid ones.
    func generateSentences(
        allowedTerms: Set<Term>,
        focusTerms: [Term],
        learningState: LearningStateSummary,
        count: Int
    ) async throws -> [AISentenceModel]
}
```

`allowedTerms` is the hard constraint from §2.1. `focusTerms` are the terms to
*prioritize* within that set (the chosen categories' terms, excluding the always-added
personal information). `LearningStateSummary` is a small struct replacing the raw
flashcard dump — see §4.3.

Both generators return `AISentenceModel` with `practiceType` left as `.words`;
`assignPracticeTypes(to:modeSelection:)` already handles the split downstream and should
not move.

### 3.2 Selection logic

```swift
private static func resolveGenerator() -> SentenceGenerating {
    if #available(iOS 26.0, macOS 26.0, *),
       case .available = SystemLanguageModel.default.availability {
        return FoundationModelsGenerator()
    }
    return SentenceBankGenerator.shared
}
```

Check availability **at call time, not at app launch** — a user can toggle Apple
Intelligence off, and the model can be mid-download (`.modelNotReady`).

`FoundationModelsGenerator` must fall back to the bank on throw or short return:

```swift
let sentences = (try? await primary.generateSentences(...)) ?? []
if sentences.count < minimumAcceptable {
    return try await SentenceBankGenerator.shared.generateSentences(...)
}
```

---

## 4. Component: `SentenceBankGenerator`

**Build this first.** It is the path most users take, it has no unknowns, and it becomes
the safety net that lets the Foundation Models path fail gracefully.

New file: `Talking Fingers/Practice/Services/SentenceBankGenerator.swift`
New resource: `Talking Fingers/Resources/SentenceBank.json` (add to the app target)

### 4.1 Bank format

```json
{
  "version": 1,
  "sentences": [
    {
      "id": "verbs-0042",
      "english": "I want water.",
      "gloss": ["ME", "WANT", "WATER"],
      "category": "verbs"
    }
  ]
}
```

- `gloss` is a **pre-split array of raw `Term` values**, not a string. The bank is
  validated at build time, so runtime tokenization only adds failure modes.
- `category` is the single **owning category** (§4.2) — the selection key. Every gloss
  token must come from that category or `.personalInformation`.
- `id` is stable and used for the recently-served exclusion set (§4.4). Do not renumber
  on edit; append new IDs.

### 4.2 One bank per category; select by eligible category

Each sentence belongs to exactly one **owning category**, and its gloss is drawn only
from `owningCategory ∪ personalInformation`. Selection is then a simple union:

```
candidates = sentences whose owningCategory ∈ eligibleCategories
```

Because every sentence is confined to one category plus the always-allowed personal
information, a sentence is automatically valid for *any* selection that includes its
owning category — `allowedTerms` only grows as more categories become eligible. Seven
per-category banks therefore cover all 127 category combinations with no
per-combination authoring.

Also author a pool owned by `.personalInformation` itself, which is eligible for every
selection and carries a day-one learner (§2.5).

Multi-category sentences are **not** part of the foundation. If added later for variety,
they need an explicit category list and are only eligible when *all* of those categories
are eligible.

> Note: there is deliberately **no per-term subset test** here. See §2.1 for why it was
> rejected.

### 4.3 Runtime behaviour

1. Load and decode `SentenceBank.json` once, lazily, into memory. Cache it
   (`static let shared`).
2. Resolve each `gloss` entry via `Term(rawValue:)`. **Drop any sentence with an
   unresolvable token at load time**, with an `assertionFailure` in debug — that means
   the bank and `Term.swift` have drifted.
3. Filter to sentences whose owning category is in `eligibleCategories` (§2.1).
   **Do not union in `.personalInformation` here** — see §2.4.
4. Drop recently-served entries (§4.4), reverting to the full candidate set if that
   would leave fewer than `count`.
5. **Uniform random draw** of `count` from what remains. No ranking, no weighting —
   every eligible sentence is equally likely. See §2.3 for why per-sentence scoring was
   removed.
6. **If fewer than `count` remain**, return what exists rather than throwing. The
   category-level selection in §2.1 makes a genuinely empty result almost impossible;
   the one real case is a day-one learner, covered by the greetings fallback in §2.5.

### 4.4 Avoiding repetition

The bank is finite and the eligible subset may be small, so naive random selection
repeats quickly. Persist recently served sentence IDs in `UserDefaults` (not worth a
SwiftData model) and exclude the last ~3× `count`. Reset the exclusion set when it would
leave too few candidates.

### 4.5 Producing the bank content — `Tools/generate_sentence_bank.py`

**Built and shipped.** The bank is generated, not hand-authored:

```sh
python3 Tools/generate_sentence_bank.py     # rewrites Resources/SentenceBank.json
```

The script parses `Term.swift` directly (comments stripped, backticks handled) so it
cannot drift from the vocabulary, then expands grammatical templates over the real
per-category term lists and samples down to the target count. Current output:

| Category | Count |
|---|---|
| alphabet | 320 |
| numbers | 320 |
| greetings | 320 |
| personal information | 262 |
| family | 320 |
| verbs | 320 |
| locations | 253 |
| **total** | **2,115** |

**To grow or change the bank, edit the templates in the script and re-run** — do not
hand-edit `SentenceBank.json`, which is generated output.

Structural guards inside the script's `Bank.add()` (learned the hard way — the first
run shipped `SHE LIKE HER`, an ungrammatical dangling possessive):

- gloss tokens must be a subset of `owningCategory ∪ personalInformation`;
- gloss may not **end** on a possessive (it has to own the noun that follows);
- gloss may not consist solely of pronouns and possessives.

Known limits of template generation, stated plainly:

- It buys **valid tokens and correct structure, not idiomatic ASL**. That is the price
  of determinism.
- Category vocabulary bounds the ceiling. `personalInformation` has only four verbs
  (`LIVE`, `WORK`, `LIKE`, `GO`), so its variety is inherently limited.
- **Still outstanding: have a sample reviewed by someone who signs.** A shipped bank is
  permanent in a way per-request generation is not. This has not been done.

#### The transitive-verb gap — a vocabulary problem, not a template problem

`SentenceGenerationService.allowedCategories` excludes `commonObjects`,
`commonDescriptors`, `dateTime`, and `feelingsEmotions`. The consequence for the verbs
bank: **there are almost no object nouns in scope.** The only nouns a verbs-owned
sentence can reach are `NAME`, `AGE`, `WORK`, `STUDENT`, `FAVORITE` (from personal
information).

So `MAKE`, `TAKE`, `GIVE`, `GET`, `TELL`, `SAY`, and `FEEL` cannot be given objects and
read wrong without them ("I want to make.", "He gives."). They are excluded from the
objectless templates via `NEEDS_OBJECT`, and only `SAY`/`KNOW`/`TELL` reappear, paired
with the one workable object (`… my name`). **The rest of those verbs therefore get very
little sentence practice.**

The fix is not more templates — it is **adding `commonObjects` to `allowedCategories`**.
`FOOD`, `WATER`, `BOOK`, `PHONE`, `COMPUTER`, `CAR`, `HOUSE`, `DOG`, `CAT`, `MOVIE`,
`MUSIC` would unlock `ME EAT FOOD`, `ME WANT WATER`, `SHE MAKE FOOD`, `HE WATCH MOVIE`
and hundreds more. That is a product decision (it adds a practice category), so it is
flagged here rather than made.

#### Template review — classes found and fixed

The first generated bank shipped several bad classes. All were template-combination
bugs, not individual bad sentences, and all are now guarded in the generator:

| Class | Example | Fix |
|---|---|---|
| Verb × question-word cross-product | "when does he live?" | `PI_VERB_QUESTIONS` enumerates valid pairings |
| Transitive verb, no object | "why do you like?", "I want to make." | `LIKE` takes no bare clause; `NEEDS_OBJECT` |
| Farewell + question | "Bye, where do we live?" | openers split into greeting vs farewell |
| Bare yes/no oddity | "Does he live?" | `PI_BARE_VERBS` excludes `LIVE` |
| Plural possessor, singular noun | "Our name is Amy.", "our husband" | `NAME_POSSESSIVES`, `NOT_SHARED` |
| Plural agreement | "Are we a student?" | `PLURAL_SUBJECTS` |
| English naming an unglossed word | "where does my family live" → `MY LIVE WHERE` | template removed |
| Yes/no question given a question word | "Do you know Amy?" → `… WHO` | ASL marks yes/no with facial grammar, no wh-token |

**When adding templates, re-run the audit.** Cross-products between a verb list and a
question-word list, or between an opener list and a clause list, are where every one of
these came from.

**Design decision worth preserving:** the idiomatic orderings `HOW YOU` ("how are you?")
and `WHAT UP` were removed in favour of `YOU HOW`, because the app's own glossing rules
teach "question word last." A learner should not meet a rule in the prompt and
counterexamples in the bank. If the rule ever changes, revisit this.

### 4.6 Build-time validator

New file: `Tools/validate_sentence_bank.swift` (the repo already has `Tools/`)

Fails on:
- Any gloss token not in `Term.allCases`
- A hyphenated compound split into parts (`GOOD` immediately followed by `MORNING`)
- Duplicate English text or duplicate gloss sequences
- Empty gloss, or empty/whitespace English
- Any sentence whose gloss is not a subset of `(its own category ∪ personalInformation)`
  — this is the invariant §4.2 relies on, and violating it means a sentence can surface
  for a learner who hasn't studied the term's category
- Duplicate `id`, or an `id` whose prefix disagrees with `category`
- Per-category count below threshold

Warns on:
- `ME` directly before a noun where `MY` is likely intended

---

## 5. Component: `FoundationModelsGenerator`

> ⚠️ **Superseded by §9.** This section describes what was built and is accurate as a
> record of the design, but the conclusion it was written toward did not hold. The
> generator is implemented, compiles, and is **off by default**. Read §9 before acting
> on anything here.

File: `Talking Fingers/Practice/Services/FoundationModelsGenerator.swift`

**API verified against the macOS 26.5 SDK `.swiftinterface`** — the symbols below exist
as written.

### 5.1 Availability

```swift
import FoundationModels

switch SystemLanguageModel.default.availability {
case .available:
    break
case .unavailable(let reason):
    // .deviceNotEligible | .appleIntelligenceNotEnabled | .modelNotReady
    // Log and hand back to the bank. Never block generation on this.
}
```

### 5.2 Guided generation — constrain to the allowed set, not all terms

The scoping rule in §2 makes this cleaner than a static enum would be. Rather than
declaring `Term` as a 190-case `@Generable` enum, **build a `GenerationSchema` per
request from `allowedTerms`**. The SDK exposes:

```swift
func respond<Content>(
    to prompt: String,
    generating type: Content.Type,
    includeSchemaInPrompt: Bool = true,
    options: GenerationOptions = GenerationOptions()
) async throws -> Response<Content> where Content: Generable

func respond(
    to prompt: String,
    schema: GenerationSchema,
    includeSchemaInPrompt: Bool = true,
    options: GenerationOptions = GenerationOptions()
) async throws -> Response<GeneratedContent>
```

Two viable routes, in order of preference:

1. **Dynamic `GenerationSchema`** built from `allowedTerms` — a per-request enum of only
   the 40–60 permitted tokens. Smaller schema, and it enforces §2's category scoping
   *structurally*: the decoder cannot emit a term outside the learner's selection.
2. **Static `@Generable` `Term` enum** with all ~190 cases, relying on the prompt for
   scoping. Simpler, but the schema is large and scoping becomes advisory again.

Try route 1 first. Fall back to route 2, then to `gloss: String` plus the existing
tokenizer, if the dynamic schema proves awkward.

**Watch `includeSchemaInPrompt`.** It defaults to `true`, which injects the schema into
the prompt and consumes context. With a large enum this may be a significant share of
the 4K window — measure it, and try `false` once the model reliably produces the shape.

### 5.3 Prompt budget

The existing prompt will not fit. It currently emits:

| Section | Approx. tokens |
|---|---|
| Rules, examples, formatting instructions | ~1,500 |
| Full `Term.allCases` vocabulary list | ~600 |
| **One line per flashcard** | ~10 per card — **unbounded** |

Write a new compact prompt builder rather than reusing `generatePromptForLLM`:

- **Vocabulary list**: now only the allowed subset (~40–60 terms), not 190. If route 1 in
  §5.2 works, drop it from the prompt entirely — the schema carries it.
- **Replace the per-flashcard dump** with a `LearningStateSummary` struct: counts per
  `ProgressType` plus the focus terms. `analyzeLearningState` already produces exactly
  this shape as a string; reuse its logic against *real* progress data (§2.3).
- Keep: glossing rules, subject/possessive pronoun distinction, hyphenated-token rule,
  SVO-default rule, and 2–3 few-shot examples. All corrected in commit `03e45a2`.
- Put stable rules in `LanguageModelSession(instructions:)`, per-request focus terms in
  the prompt.

Assert the prompt stays under budget during development.

### 5.4 Session use

```swift
let session = LanguageModelSession(instructions: glossingRules)
let response = try await session.respond(
    to: prompt,
    generating: GeneratedSentenceSet.self
)
```

- Generation is slow relative to a network call — expect seconds. Confirm the existing
  loading state covers this path.
- `LanguageModelSession` is stateful. Prefer one per generation unless profiling says
  otherwise.
- Catch `GenerationError` (including guardrail/refusal cases) and fall through to the
  bank rather than surfacing an error.

### 5.5 Still run the validator

Guided generation guarantees *valid tokens*, not *good sentences*. Keep deduplication and
`normalizeFirstPersonPronouns` — a 3B model may still produce `ME NAME` or repeat itself.

---

## 6. Retiring the Claude path

1. **Delete `AIViewModel.swift`**, or reduce it to the `convertToAISentences` helpers
   moved somewhere shared (`Talking Fingers/Practice/Utilities/` is a reasonable home).
   The Firestore key fetch, `waitForAPIKey`, and all networking go away.
2. **Remove the `API_KEYS` block from `firestore.rules`** (or set `allow read: if false`).
   The current rule lets any signed-in user read the API key.
3. **Delete the `API_KEYS/Anthropic` document** in the Firebase console; revoke both the
   Anthropic key and the old OpenAI key.
4. Remove now-unused `AIError` cases (`missingAPIKey`, `apiError`, `refused`).

### 6.1 Unrelated but blocking — deployed Firestore rules are wrong

The **deployed** rules do not match `firestore.rules` in the repo. The live version
(Apr 29, 2026) protects `/users/{userId}` **lowercase**, while `Firebase.swift:16` uses
`db.collection("Users")` **capital U**. Firestore paths are case-sensitive, so **all
profile reads and writes are currently denied**, falling through to default-deny.

Deploy the repo's rules via `firebase deploy --only firestore:rules`, or paste into the
console. This is a live bug affecting user data, independent of this work — and §2.3
depends on progress data syncing correctly.

---

## 7. Order of work — outcome

| # | Step | Status |
|---|---|---|
| 1 | Fix progress plumbing (§2.6) | ✅ done |
| 2 | Allowed-vocabulary computation (§2.1) | ✅ done — `VocabularyScope` |
| 3 | `SentenceGenerating` protocol + service refactor | ✅ done |
| 4 | `SentenceBankGenerator` + validator | ✅ done |
| 5 | Grow the bank (§4.5) | ✅ done — 2,115 via `Tools/generate_sentence_bank.py` |
| 6 | `FoundationModelsGenerator` | ✅ built, ❌ **parked** — see §9 |
| 7 | Evaluate quality | ✅ done — bank wins, see §9 |
| 8 | Retire the Claude path (§6) | ✅ done — `AIViewModel` deleted, `API_KEYS` rule removed |

**Still outstanding:**

- **Deploy `firestore.rules`** (§6.1). The repo file is correct; the *deployed* rules
  still protect lowercase `/users/{userId}` while the code uses `Users`, so profile
  reads and writes are denied in production. This is a live bug and unrelated to
  sentence generation.
- **Revoke the old Anthropic and OpenAI keys** and delete the `API_KEYS/Anthropic`
  Firestore document. The rule is gone; the secrets are still live.
- **Have a sample of the bank reviewed by someone who signs** (§4.5).

The original ordering, for reference:



1. **Fix progress plumbing (§2.3).** Pass real `[FlashcardModel]` into
   `SentenceGenerationService`. Everything else depends on this, and it fixes a latent
   bug on its own.
2. **Implement allowed-vocabulary computation (§2.1)** including the empty-pool fallback,
   and narrow the `convertToAISentences` membership check to it.
3. **`SentenceGenerating` protocol** + refactor the service to resolve a generator, with
   `AIViewModel` temporarily conforming. Verify the app still builds.
4. **`SentenceBankGenerator`** with a seed bank (~50 sentences across 2–3 categories) and
   the validator. Ship-quality path for most users.
5. **Grow the bank** per §4.5. Long pole; parallelizable with step 6.
6. **`FoundationModelsGenerator`**, prototyped on the **Mac target first** — macOS is at
   26.0 and Apple-silicon Macs support Apple Intelligence, so no device needed. First
   question to answer: does a dynamic `GenerationSchema` from `allowedTerms` work?
7. **Evaluate quality.** Generate 50 sentences on-device, run them through the validator,
   compare against bank sentences. If worse, ship bank-only and keep the generator behind
   a debug flag.
8. **Retire the Claude path** and fix the Firestore rules (§6).

Steps 1–5 deliver a working, free, universal feature. Steps 6–7 are an enhancement whose
value is unproven until measured.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| ~~Dynamic `GenerationSchema` may be awkward or unsupported~~ | **Did not materialize.** `DynamicGenerationSchema(anyOf:)` handled a 40–60 term enum fine. |
| ~~Schema in prompt may eat the context window~~ | **Did not materialize.** The scoped vocabulary kept the prompt well inside budget. |
| **3B model may produce poor ASL gloss** | **This is what happened.** Bank shipped instead — §9. |
| Too few bank sentences for a given selection | Author per-category (§4.2); graceful degradation (§4.3 step 6). |
| Day-one learner has no eligible categories | Greetings starter fallback (§2.5). |
| Sentence contains a term the learner hasn't reached | Accepted tradeoff (§2.1); `SignHintSheetView` covers an unknown sign. The familiarity sort that used to soften this was removed (§2.3) — the planned category gating in §2.4 is the intended mitigation instead. |
| Bank and `Term.swift` drifting apart | Validator in CI or a pre-commit hook (§4.6). |
| On-device latency in the practice flow | Measure; consider generating ahead of need. |

---

## 9. Evaluation of Foundation Models — why it is parked

> This section supersedes the optimism in §5. It records what was actually built, what
> it produced, and what would have to be different to make it work.

### 9.1 What was built

Everything §5 called for: a per-request `GenerationSchema` built from `allowedTerms`
(route 1 — it works, `DynamicGenerationSchema(anyOf:)` handles a 40–60 term enum fine),
a compact prompt under the context budget, `LanguageModelSession(instructions:)` carrying
the stable glossing rules, and post-validation via `SentenceValidation`.

Tested on an M3 Pro, macOS 26.5.2, Xcode 26.6, with Apple Intelligence enabled.

### 9.2 What it produced

| Requested | Generated gloss | Problem |
|---|---|---|
| "My name is John" | `NAME ME J` | possessive→subject, word order, name truncated to one letter |
| "What is your favorite color?" | `FAVORITE WHAT YOUR` | `COLOR` isn't in the vocabulary; question word stranded mid-gloss; dangling possessive |
| "Hello" | `HELLO ME` | spurious trailing pronoun |
| "Meet your friend" | `MEET NAME YOU` | `FRIEND` isn't in the vocabulary → substituted `NAME` |
| "Good morning" | `GOOD MORNING ME` | spurious trailing pronoun |

### 9.3 Root causes

1. **The schema constrains membership, not order or arity.** `[AllowedTerm]` permits any
   permutation and any length within bounds. `GOOD MORNING ME` is a perfectly legal
   instance of that type. No prompt rule reliably fixes this on a 3B model.
2. **`english` is an unconstrained `String`.** Nothing structurally ties it to the gloss,
   so the model writes English about *color* or *friend* — concepts with no `Term` — then
   approximates it with whatever tokens exist. An explicit "write the gloss first, never
   write English you cannot gloss" instruction was added and **ignored**.
3. **Instruction-following is the binding constraint.** The ME/MY rule, the fingerspelling
   rule, and the vocabulary-bounded-English rule were each stated explicitly and each
   violated.

### 9.4 Why more validation is not the answer

Four structural guards were added to `SentenceValidation` (§9.5). They catch the first
two rows of the table above. **They do not catch the last three** — `HELLO ME`,
`MEET NAME YOU`, and `GOOD MORNING ME` are all structurally well-formed and semantically
wrong. The failure mode moved from *malformed* to *plausible-but-wrong*, which is the
category no cheap validator catches. Each new guard also discards more output, pushing
the request below the usable threshold and onto the bank anyway.

### 9.5 The structural guards (shipped, still useful)

`SentenceValidation.isStructurallyValid(_:)` rejects gloss that:

1. ends on a possessive (`MY`/`YOUR`/`HIS`/`HER`/`OUR`/`THEIR`/`ITS`) — it has to own
   a following noun;
2. consists solely of pronouns and possessives — no content;
3. contains a question word anywhere but the final position — ASL puts it last;
4. contains an orphan alphabet token — fingerspelling is one token per letter, so a
   lone letter is a truncated name.

These run on **any** generator's output, so they stay valuable if a future backend is
added. The bank passes all four with zero violations across 2,115 entries.

### 9.6 What would have to change to revisit this

The only fix that addresses the root cause is **constraining grammatical structure, not
just vocabulary** — a schema with typed slots rather than a flat token array:

```swift
@Generable struct GeneratedSentence {
    let subject: Pronoun?     // enum over subject pronouns only
    let verb: VerbTerm        // enum over verbs only
    let object: NounTerm?     // enum over nouns only
}
```

That makes `GOOD MORNING ME` unrepresentable. It requires a part-of-speech classification
`Term` does not currently have (`TermCategory` is only a rough proxy — `personalInformation`
mixes pronouns, verbs, and nouns).

**But note where that lands:** a model filling fixed grammatical slots with vocabulary is
exactly what `Tools/generate_sentence_bank.py` already does — deterministically, offline,
with validation, and without a hardware gate. Constrain the model enough to be correct at
ASL gloss and it converges on the template generator, minus determinism, plus latency and
an iPhone-15-Pro requirement.

**Recommended triggers for revisiting:**

- Apple ships a materially stronger on-device model (retest with
  `-SentenceBackendOverride foundationModels`; the code path is intact).
- A use case appears that plays to the model's actual strength — fluent English — rather
  than its weakness at rigid symbolic constraints. Two candidates: generating the *English*
  for a gloss the app already chose, or ranking/selecting bank sentences for a learner's
  context.

**Before investing again, measure.** A standalone Swift CLI linking `FoundationModels`
that runs the current schema and prompt N times and reports the `SentenceValidation` pass
rate would turn "it seems poor" into a number, and would double as a regression harness.
This was scoped but not built.

---

## 10. Verification

- `xcodebuild -project "Talking Fingers.xcodeproj" -scheme "Talking Fingers" -destination 'generic/platform=iOS' build` succeeds.
- Generation on a **non-Apple-Intelligence device or simulator** returns bank sentences,
  never an error.
- Generation on an Apple-silicon Mac returns Foundation Models sentences.
- **Every gloss token is a member of the request's `allowedTerms`** — not merely of
  `Term.allCases`. Test with a single category (e.g. `family`) and assert no term from an
  unselected category (e.g. `HOSPITAL`) appears.
- Picking `family` alone returns grammatical sentences (proves the personal-information
  union works).
- With no categories selected, sentences come only from categories where the learner has
  at least one non-`.new` term, plus personal information.
- A learner with zero non-`.new` cards still gets sentences (greetings fallback, §2.5).
- A learner early in a category still gets a full set of sentences from it — verify the
  rejected per-term gate has not crept back in (§2.1).
- No sentence splits a hyphenated compound (`GOOD` immediately followed by `MORNING`).
- Possessives are used before owned nouns (`MY NAME`, not `ME NAME`).
- No network request is made during generation.
