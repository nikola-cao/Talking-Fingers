//
//  VisionExerciseView.swift
//  Talking Fingers
//

import SwiftUI
import SwiftData

/// Camera-based exercise view that grades the user's sign in real time.
/// Mirrors the layout and top-bar conventions of `MultipleChoice` and `LearnModeView`.
struct VisionExerciseView: View {

    // MARK: - Configuration
    let currentCard: FlashcardModel
    var progress: Double
    @Binding var inputMode: ExerciseInputMode
    /// Called when the user taps Leave; on macOS (inline) this replaces dismiss().
    var onLeave: (() -> Void)? = nil
    var onNext: (FlashcardModel) -> Void = { _ in }
    var onFinished: (() -> Void)? = nil
    var finishAfterCurrentCard: Bool = false
    var nextButtonTitle: String = "Next Word"

    // MARK: - Environment
    @Environment(FlashcardVM.self) private var flashcardVM
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataVM.self) private var dataVM
    @Query private var users: [User]

    // MARK: - State
    @State private var showHintPopup: Bool = false
    @State private var isPassed: Bool = false
    @State private var confidenceScore: Double = 0
    /// Captured at runtime so the camera card scales to the available window/screen height.
    @State private var viewHeight: CGFloat = 600

    // MARK: - Constants
    private let tfGreen      = TFColors.tfGreen
    private let tfGreenText  = TFColors.tfGreenText

    /// 58 % of the view height, clamped so it never looks tiny on small phones or
    /// absurdly tall on large displays / macOS windows.
    private var cameraHeight: CGFloat {
        min(max(viewHeight * 0.58, 280), 560)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            TFColors.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 20) {
                        cameraCard

                        if isPassed {
                            nextWordButton
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(TFColors.white)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        // Capture the runtime view height so cameraHeight can adapt.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in viewHeight = h }
            }
        )
        // Hint popup
        .popupHost(isPresented: $showHintPopup) {
            HintPopUpComponent(
                hintText: hintText
            ) {
                showHintPopup = false
            }
        }
        // Reset local state whenever the card changes
        .onChange(of: currentCard.id) { _, _ in
            isPassed = false
            confidenceScore = 0
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        SessionTopBar(
            progress: progress,
            onLeave: {
                #if os(macOS)
                onLeave?()
                #else
                dismiss()
                #endif
            }
        ) {
            ExerciseSettingsMenu(mode: $inputMode)
        }
    }

    // MARK: - Camera Card
    private var cameraCard: some View {
        SigningCameraCard(
            word: currentCard.term.displayName,
            showSaveButton: true,
            showStuckButton: false,
            showSkipButton: true,
            cameraHeight: cameraHeight,
            isHintActive: showHintPopup,
            onConfidenceChange: { score in
                confidenceScore = score
                // `SigningPracticeView` already emits only once the camera VM
                // reaches its "good" threshold, so avoid applying a second,
                // stricter gate here.
                if !isPassed {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPassed = true
                    }
                }
            },
            onHintTap: { showHintPopup = true },
            onSkipTap: { handleSkip() }
        )
        .id(currentCard.id)
    }

    // MARK: - Next Word Button
    private var nextWordButton: some View {
        Button {
            handlePass()
        } label: {
            Text(nextButtonTitle)
                .font(.jakartaHeadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tfGreen)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private var hintText: String {
        "Focus on the handshape for '\(currentCard.term.displayName)'"
    }

    private func handlePass() {
        flashcardVM.handleAnswer(for: currentCard, correct: true, user: users.first, dataVM: dataVM)
        advanceToNext()
    }

    private func handleSkip() {
        flashcardVM.handleAnswer(for: currentCard, correct: false, user: users.first, dataVM: dataVM)
        advanceToNext()
    }

    private func advanceToNext() {
        isPassed = false
        confidenceScore = 0
        if finishAfterCurrentCard {
            if let onFinished {
                onFinished()
            } else {
                finishSession()
            }
            return
        }
        
        if let next = flashcardVM.nextCard() {
            onNext(next)
        } else {
            finishSession()
        }
    }
    
    private func finishSession() {
        #if os(macOS)
        onLeave?()
        #else
        dismiss()
        #endif
    }
}

// MARK: - Preview

#Preview("Vision Exercise") {
    let vm = FlashcardVM()
    vm.flashcards = FlashcardVM.dummyFlashcards
    let card = FlashcardModel(term: .hello, id: UUID(), category: .greetings)
    return VisionExerciseView(
        currentCard: card,
        progress: 0.3,
        inputMode: .constant(.camera),
        onNext: { _ in }
    )
    .environment(vm)
    .environment(SwiftDataVM())
}
