//
//  MultipleChoice.swift
//  Talking Fingers
//
//  Created by Isha Jain on 3/16/26.
//

import SwiftUI
import SwiftData

struct MultipleChoice: View {

    // MARK: - Configuration
    let question: String
    let options: [String]
    let correctAnswer: String

    // Spaced repetition integration
    let currentCard: FlashcardModel
    var onNext: (FlashcardModel) -> Void = { _ in }

    // Progress (0.0 – 1.0) — passed in by the caller to reflect real progress
    var progress: Double

    // Mode binding — lets the user toggle Camera vs Flashcards mid-session
    @Binding var inputMode: ExerciseInputMode

    // Called when the user taps Leave; on macOS (inline) this replaces dismiss().
    var onLeave: (() -> Void)? = nil

    // MARK: - Environment (Observation framework)
    @Environment(FlashcardVM.self) private var flashcardVM
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataVM.self) private var dataVM
    @Query private var users: [User]

    // MARK: - State
    @State private var selectedAnswer: String? = nil
    @State private var isSaved: Bool = false
    @State private var showHintPopup: Bool = false
    @State private var showCorrectPopup: Bool = false
    @State private var showIncorrectPopup: Bool = false

    // MARK: - Brand Colors
    private let tfGreen = TFColors.tfGreen
    private let tfGreenText = TFColors.tfGreenText

    // MARK: - Init
    init(
        question: String,
        options: [String],
        correctAnswer: String,
        currentCard: FlashcardModel,
        inputMode: Binding<ExerciseInputMode> = .constant(.flashcards),
        onLeave: (() -> Void)? = nil,
        onNext: @escaping (FlashcardModel) -> Void = { _ in },
        progress: Double
    ) {
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.currentCard = currentCard
        self._inputMode = inputMode
        self.onLeave = onLeave
        self.onNext = onNext
        self.progress = progress
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            TFColors.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ────────────────────────────────────────────────
                topBar

                // ── Card ───────────────────────────────────────────────────
                VStack(spacing: 20) {
                    questionCard
                }
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // ── Submit (bottom area) + private tiny level badge ───────
                VStack(spacing: 6) {
                    submitButton
                        .frame(maxWidth: 1100)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    HStack {
                        tinyProgressBadge
                        Spacer()
                    }
                    .frame(maxWidth: 1100)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
            }
            .background(TFColors.white)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .frame(maxHeight: .infinity)
        // Hint popup like LearnModeView
        .popupHost(isPresented: $showHintPopup) {
            HintPopUpComponent(
                hintText: "This sign resembles a B shape"
            ) {
                showHintPopup = false
            }
        }
        // Correct answer popup
        .popupHost(isPresented: $showCorrectPopup) {
            CorrectResultPopUpComponent(
                message: "You got it right!",
                onNext: {
                    advanceToNextCard()
                }
            )
        }
        // Incorrect answer popup
        .popupHost(isPresented: $showIncorrectPopup) {
            IncorrectResultPopUpComponent(
                message: "Correct answer: \(correctAnswer)",
                onNext: {
                    advanceToNextCard()
                }
            )
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    #if os(macOS)
                    onLeave?()
                    #else
                    dismiss()
                    #endif
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.jakarta(size: 16, weight: .medium))

                        Text("Leave")
                            .font(.jakarta(size: 16, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            HStack(spacing: 12) {

                GeometryReader { geo in
                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(TFColors.trackBlueLight)

                        Capsule()
                            .fill(TFColors.tabBlue)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 10)

                ExerciseSettingsMenu(mode: $inputMode)
            }
            .padding(.horizontal, 20)

        }
        .padding(.top, 10)
    }

    // MARK: - Question Card
    private var questionCard: some View {
        VStack(spacing: 16) {

            // Save + Hint
            HStack {
                Button {
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(tfGreenText)
                        .padding(14)
                        .background(Circle().fill(tfGreen.opacity(0.25)))
                        .scaleEffect(1.1)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showHintPopup = true
                } label: {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                        .padding(14)
                        .background(Circle().fill(Color.orange.opacity(0.2)))
                        .scaleEffect(1.1)
                }
                .buttonStyle(.plain)
            }
            
            if let gifFileName = currentCard.gifFileName ?? currentCard.term.defaultGifFileName {
                GIFView(gifFileName: gifFileName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No GIF available")
            }

            Spacer(minLength: 8)

            // Question text (if desired)
            if !question.isEmpty {
                Text(question)
                    .font(.jakartaHeadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Answer options
            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    optionRow(option, isSelected: selectedAnswer == option)
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1.5)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // Tiny, subtle badge for internal use only (bottom-left under submit)
    private var tinyProgressBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(for: currentCard.progress))
                .frame(width: 6, height: 6)
            Text("Level: \(title(for: currentCard.progress))")
                .font(.jakartaCaption2)
                .foregroundColor(Color.secondary.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0xF2F2F7).opacity(0.6))
                )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private func title(for progress: ProgressType) -> String {
        switch progress {
        case .new: return "New"
        case .learning: return "Learning"
        case .polishing: return "Polishing"
        case .mastered: return "Mastered"
        }
    }

    private func color(for progress: ProgressType) -> Color {
        switch progress {
        case .new: return .gray
        case .learning: return .orange
        case .polishing: return .blue
        case .mastered: return .green
        }
    }
    // MARK: - Option Row
    @ViewBuilder
    func optionRow(_ text: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedAnswer = text
            }
        } label: {
            HStack {
                Text(text)
                    .font(.jakarta(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? TFColors.sandGold
                        : Color.white
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            handleSubmission()
        } label: {
            Text("Submit")
                .font(.jakartaHeadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tfGreen)
                )
        }
        .disabled(selectedAnswer == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedAnswer)
        .buttonStyle(.plain)
    }

    private func handleSubmission() {
        guard let selected = selectedAnswer else { return }
        let isCorrect = (selected == correctAnswer)

        // Update spaced repetition progress even when user profile is absent.
        flashcardVM.handleAnswer(for: currentCard, correct: isCorrect, user: users.first, dataVM: dataVM)

        if isCorrect {
            withAnimation(.easeInOut(duration: 0.25)) {
                showCorrectPopup = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showIncorrectPopup = true
            }
        }
    }

    private func advanceToNextCard() {
        // Close popups
        showCorrectPopup = false
        showIncorrectPopup = false

        // Ask VM for next card
        if let next = flashcardVM.nextCard() {
            // Reset selection state
            selectedAnswer = nil
            isSaved = false
            // Delegate navigation/presentation to parent
            onNext(next)
        } else {
            // No more cards — return to parent
            #if os(macOS)
            onLeave?()
            #else
            dismiss()
            #endif
        }
    }
}

// MARK: - Previews

#Preview("Single Card (original)") {
    let vm = FlashcardVM()
    let card = FlashcardModel(
        term: .hello,
        id: UUID(),
        category: .greetings
    )
    MultipleChoice(
        question: "What sign is being shown?",
        options: ["Hello", "Goodbye", "Wassup", "See you"],
        correctAnswer: "Hello",
        currentCard: card,
        inputMode: .constant(.flashcards),
        onNext: { _ in },
        progress: 0.0
    )
    .environment(vm)
    .environment(SwiftDataVM())
    .modelContainer(for: [FlashcardModel.self, User.self], inMemory: true)
}

#Preview("Zero GIF") {
    let vm = FlashcardVM()
    let card = FlashcardModel(
        term: .zero,
        id: UUID(),
        category: .numbers
    )
    return MultipleChoice(
        question: "What sign is being shown?",
        options: ["0", "1", "2", "3"],
        correctAnswer: "0",
        currentCard: card,
        onNext: { _ in },
        progress: 0.0
    )
    .environment(vm)
    .environment(SwiftDataVM())
    .modelContainer(for: [FlashcardModel.self, User.self], inMemory: true)
}

#Preview("Spaced Repetition Tester") {
    MultipleChoiceSRTester()
}
