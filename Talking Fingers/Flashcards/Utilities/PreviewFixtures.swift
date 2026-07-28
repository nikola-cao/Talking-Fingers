//
//  PreviewFixtures.swift
//  Talking Fingers
//
//  Dummy flashcard decks and interactive harnesses used only by
//  SwiftUI #Preview blocks.
//

import SwiftUI

extension FlashcardVM {
    /// Seed deck for SwiftUI previews (e.g. VisionExerciseView).
    static let dummyFlashcards: [FlashcardModel] = {
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now)!
        }

        return [
            FlashcardModel(term: .hello, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .greetings, gifFileName: Term.hello.defaultGifFileName),
            FlashcardModel(term: .a, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .greetings),
            FlashcardModel(term: .bye, id: UUID(), lastSucceeded: daysAgo(10), starred: false, progress: .learning, category: .greetings),
            FlashcardModel(term: .nice, id: UUID(), lastSucceeded: daysAgo(3), starred: true, progress: .learning, category: .greetings),
            FlashcardModel(term: .how, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .polishing, category: .greetings),

            FlashcardModel(term: .one, id: UUID(), lastSucceeded: daysAgo(8), starred: false, progress: .learning, category: .numbers),
            FlashcardModel(term: .zero, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .numbers),
            FlashcardModel(term: .two, id: UUID(), lastSucceeded: daysAgo(2), starred: false, progress: .polishing, category: .numbers),
            FlashcardModel(term: .three, id: UUID(), lastSucceeded: daysAgo(5), starred: true, progress: .polishing, category: .numbers),
            FlashcardModel(term: .four, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .numbers),

            FlashcardModel(term: .good, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .commonDescriptors),
        ]
    }()
}

// MARK: - Multiple choice spaced-repetition preview harness

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: Date())!
}

private func makeDummyFlashcards() -> [FlashcardModel] {
    var cards: [FlashcardModel] = []

    cards += [
        FlashcardModel(term: .hello, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .greetings),
        FlashcardModel(term: .bye, id: UUID(), lastSucceeded: daysAgo(10), starred: false, progress: .learning, category: .greetings),
        FlashcardModel(term: .hi, id: UUID(), lastSucceeded: daysAgo(3), starred: true, progress: .polishing, category: .greetings),
        FlashcardModel(term: .what, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .greetings),
        FlashcardModel(term: .nice, id: UUID(), lastSucceeded: daysAgo(20), starred: false, progress: .learning, category: .greetings),
        FlashcardModel(term: .good, id: UUID(), lastSucceeded: daysAgo(5), starred: false, progress: .polishing, category: .greetings),
        FlashcardModel(term: .morning, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .greetings),
        FlashcardModel(term: .see, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .greetings),
    ]

    cards += [
        FlashcardModel(term: .zero, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .numbers),
        FlashcardModel(term: .one, id: UUID(), lastSucceeded: daysAgo(8), starred: false, progress: .learning, category: .numbers),
        FlashcardModel(term: .two, id: UUID(), lastSucceeded: daysAgo(2), starred: false, progress: .polishing, category: .numbers),
        FlashcardModel(term: .three, id: UUID(), lastSucceeded: daysAgo(5), starred: true, progress: .polishing, category: .numbers),
        FlashcardModel(term: .four, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .numbers),
        FlashcardModel(term: .five, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .numbers),
        FlashcardModel(term: .six, id: UUID(), lastSucceeded: daysAgo(15), starred: false, progress: .learning, category: .numbers),
        FlashcardModel(term: .seven, id: UUID(), lastSucceeded: daysAgo(3), starred: false, progress: .polishing, category: .numbers),
        FlashcardModel(term: .eight, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .numbers),
        FlashcardModel(term: .nine, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .numbers),
        FlashcardModel(term: .ten, id: UUID(), lastSucceeded: daysAgo(30), starred: false, progress: .learning, category: .numbers),
    ]

    cards += [
        FlashcardModel(term: .happy, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .feelingsEmotions),
        FlashcardModel(term: .sad, id: UUID(), lastSucceeded: daysAgo(2), starred: false, progress: .mastered, category: .feelingsEmotions),
        FlashcardModel(term: .angry, id: UUID(), lastSucceeded: daysAgo(3), starred: true, progress: .polishing, category: .feelingsEmotions),
        FlashcardModel(term: .excited, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .feelingsEmotions),
        FlashcardModel(term: .tired, id: UUID(), lastSucceeded: daysAgo(12), starred: false, progress: .learning, category: .feelingsEmotions),
        FlashcardModel(term: .bored, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .feelingsEmotions),
        FlashcardModel(term: .scared, id: UUID(), lastSucceeded: daysAgo(6), starred: false, progress: .polishing, category: .feelingsEmotions),
        FlashcardModel(term: .surprised, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .feelingsEmotions),
    ]

    cards += [
        FlashcardModel(term: .mother, id: UUID(), lastSucceeded: daysAgo(9), starred: false, progress: .learning, category: .family),
        FlashcardModel(term: .father, id: UUID(), lastSucceeded: daysAgo(4), starred: false, progress: .polishing, category: .family),
        FlashcardModel(term: .brother, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .family),
        FlashcardModel(term: .sister, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .family),
        FlashcardModel(term: .grandmother, id: UUID(), lastSucceeded: daysAgo(20), starred: false, progress: .learning, category: .family),
        FlashcardModel(term: .grandfather, id: UUID(), lastSucceeded: daysAgo(2), starred: false, progress: .polishing, category: .family),
    ]

    cards += [
        FlashcardModel(term: .eat, id: UUID(), lastSucceeded: daysAgo(7), starred: false, progress: .learning, category: .verbs),
        FlashcardModel(term: .drink, id: UUID(), lastSucceeded: daysAgo(3), starred: false, progress: .polishing, category: .verbs),
        FlashcardModel(term: .go, id: UUID(), lastSucceeded: daysAgo(14), starred: false, progress: .learning, category: .verbs),
        FlashcardModel(term: .come, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .verbs),
        FlashcardModel(term: .want, id: UUID(), lastSucceeded: daysAgo(1), starred: false, progress: .mastered, category: .verbs),
        FlashcardModel(term: .get, id: UUID(), lastSucceeded: daysAgo(5), starred: false, progress: .polishing, category: .verbs),
        FlashcardModel(term: .like, id: UUID(), lastSucceeded: nil, starred: false, progress: .new, category: .verbs),
    ]

    return cards
}

private func optionsFor(card: FlashcardModel, from pool: [FlashcardModel], count: Int = 4) -> [String] {
    let distractors = pool
        .filter { $0.id != card.id }
        .map { $0.term.displayName }
        .shuffled()
        .prefix(max(0, count - 1))

    var opts = Array(distractors)
    opts.append(card.term.displayName)
    // Ensure unique and random order
    return Array(Set(opts)).shuffled()
}

struct MultipleChoiceSRTester: View {
    @State private var vm = FlashcardVM()
    @State private var current: FlashcardModel?
    @State private var currentOptions: [String] = []
    @State private var completed: Int = 0
    let target = 7

    var body: some View {
        Group {
            if let current {
                MultipleChoice(
                    question: "What sign is being shown?",
                    options: currentOptions,
                    correctAnswer: current.term.displayName,
                    currentCard: current,
                    inputMode: .constant(.flashcards),
                    onNext: { next in
                        completed += 1
                        self.current = next
                        self.currentOptions = optionsFor(card: next, from: vm.flashcards)
                    },
                    progress: Double(completed) / Double(target)
                )
                .environment(vm)
            } else {
                ProgressView("Loading cards...")
                    .onAppear {
                        seedAndStart()
                    }
            }
        }
        .padding()
    }

    private func seedAndStart() {
        vm.flashcards = makeDummyFlashcards()
        if let first = vm.nextCard() {
            current = first
            currentOptions = optionsFor(card: first, from: vm.flashcards)
        }
    }
}
