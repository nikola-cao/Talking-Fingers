//
//  LiveSigningView.swift
//  Talking Fingers
//
//  Created by Krish Prasad on 3/1/26.
//
//  Live camera signing step shared by iOS and macOS. iOS shows a fixed-height
//  camera and a 4-slot carousel of word circles; macOS fills the available
//  height and shows every word's circle at once.
//
import SwiftUI

struct LiveSigningView: View {
    @Binding var sentenceModel: AISentenceModel
    var onSentenceFinished: ((Double) -> Void)? = nil
    /// When non-nil, the top gloss line uses this color for every word (e.g. with the score overlay).
    var glossUniformColor: Color? = nil
    var externalCameraVM: CameraVM? = nil

    // Index of the word currently being signed (highlighted in black)
    @State private var currentWordIndex: Int = 0
    // Tracks which words have been completed
    @State private var completedWords: Set<Int> = []
    // Tracks which words the user explicitly skipped (not credited as completed).
    @State private var skippedWords: Set<Int> = []
    // True once the live signing view has reported a confidence at/above the
    // "good" threshold for the current word. Gates the auto-advance.
    @State private var passedThreshold: Bool = false
    // Pending auto-advance task started when threshold is first reached.
    @State private var autoAdvanceTask: Task<Void, Never>?
    // Max confidence score recorded for current word after passing threshold
    @State private var currentWordMaxScore: Double = 0
    // Stores the max score for each completed word
    @State private var wordMaxScores: [Int: Double] = [:]
    // Controls visibility of the hint sheet
    @State private var showHintSheet: Bool = false
    @State private var showCorrectCheckmark: Bool = false
    @State private var correctCheckmarkTask: Task<Void, Never>?

    /// How long to wait after reaching the threshold before auto-advancing.
    private let autoAdvanceDelay: Duration = .seconds(0.5)

    var glossWords: [Term] { sentenceModel.gloss }
    var isFinished: Bool { currentWordIndex >= glossWords.count }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private var currentTargetWord: String {
        glossWords[safe: currentWordIndex]?.rawValue ?? ""
    }

    /// `nil` once finished so the camera's comparison overlay hides.
    private var currentComparisonTarget: String? {
        guard !isFinished else { return nil }
        return currentTargetWord.lowercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sentenceModel.sentence)
                    .font(.jakarta(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "#767676"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                glossRow
            }
            .padding(.vertical, 10)

            // Live camera tied to the current target word.
            ZStack(alignment: .bottomTrailing) {
                SigningPracticeView(
                    signName: currentComparisonTarget,
                    onConfidenceChange: { confidence in
                        handleThresholdReached(confidence: confidence)
                    },
                    showsLeaveButton: false,
                    usesInternalPadding: false,
                    externalCameraVM: externalCameraVM
                )
                #if os(iOS)
                .frame(maxWidth: .infinity)
                .frame(height: 480)
                #else
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif

                if showCorrectCheckmark {
                    SigningCorrectCheckmarkOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                // Skip word button overlay
                if !isFinished {
                    Button(action: skipWord) {
                        Text("Skip word")
                            .font(.jakarta(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#97C171"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.bottom, 24)

            // Word progress circles
            wordProgressCircles
                .padding(.bottom, 24)
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
            correctCheckmarkTask?.cancel()
            correctCheckmarkTask = nil
        }
        .sheet(isPresented: $showHintSheet) {
            SignHintSheetView(
                word: currentTargetWord,
                onDismiss: {
                    showHintSheet = false
                }
            )
            #if os(macOS)
            .frame(minWidth: 900, minHeight: 600)
            #else
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            #endif
        }
    }

    // MARK: Gloss Row
    private var glossRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(glossWords.enumerated()), id: \.offset) { index, term in
                        Text(term.rawValue)
                            .font(.jakarta(size: 28, weight: .bold))
                            .foregroundColor(colorForWord(at: index))
                            .animation(.easeInOut(duration: 0.3), value: currentWordIndex)
                            .id("gloss-\(index)")
                    }
                }
            }
            .onChange(of: currentWordIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("gloss-\(newIndex)", anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Word Progress Circles

    #if os(macOS)
    /// macOS has the width to show every word's circle at once.
    private var wordProgressCircles: some View {
        HStack(spacing: 16) {
            ForEach(Array(glossWords.enumerated()), id: \.offset) { index, _ in
                circleIcon(for: index)
            }
        }
        .frame(maxWidth: .infinity)
    }
    #else
    /// iOS shows a sliding window of up to 4 circles centered on the current word.
    private var wordProgressCircles: some View {
        HStack(spacing: 0) {
            ForEach(visibleProgressIndices, id: \.self) { index in
                circleIcon(for: index)
                    .frame(maxWidth: .infinity)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: visibleProgressIndices)
    }

    private var visibleProgressIndices: [Int] {
        let visibleCount = min(4, glossWords.count)
        guard visibleCount > 0 else { return [] }
        guard glossWords.count > visibleCount else {
            return Array(0..<visibleCount)
        }

        let activeIndex = min(currentWordIndex, glossWords.count - 1)
        let maxStartIndex = glossWords.count - visibleCount
        let startIndex = activeIndex < 3 ? 0 : min(activeIndex - 2, maxStartIndex)
        return Array(startIndex..<(startIndex + visibleCount))
    }
    #endif

    /// Fixed carousel slot sizing keeps the circles evenly distributed.
    #if os(macOS)
    private static let progressCircleColumnWidth: CGFloat = 72
    private static let currentProgressCircleDiameter: CGFloat = 62
    #else
    private static let progressCircleColumnWidth: CGFloat = 92
    private static let currentProgressCircleDiameter: CGFloat = 68
    #endif
    private static let progressCircleDiameter: CGFloat = 52

    @ViewBuilder
    private func circleIcon(for index: Int) -> some View {
        let isCompleted = completedWords.contains(index)
        let isSkipped = skippedWords.contains(index)
        let isCurrent = index == currentWordIndex && !isFinished
        let wordLabel = glossWords[safe: index]?.rawValue ?? ""
        let d = isCurrent ? Self.currentProgressCircleDiameter : Self.progressCircleDiameter

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(circleFill(isCompleted: isCompleted, isSkipped: isSkipped, isCurrent: isCurrent))
                    .frame(width: d, height: d)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.jakarta(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#71A046"))
                } else if isSkipped {
                    Image(systemName: "forward.fill")
                        .font(.jakarta(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                } else if isCurrent {
                    Image(systemName: "lightbulb.max")
                        .font(.jakarta(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#F8BC3A"))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.jakarta(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#B3B3B3"))
                }
            }
            .frame(width: Self.progressCircleColumnWidth, height: Self.progressCircleColumnWidth, alignment: .center)
            .contentShape(Circle())
            .onTapGesture {
                if isCurrent {
                    showHintSheet = true
                }
            }

            Text(wordLabel)
                .font(.jakarta(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "#767676"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(isCurrent ? 1 : 0)
                .frame(height: 20)
        }
        .frame(width: Self.progressCircleColumnWidth)
        .animation(.easeInOut(duration: 0.3), value: currentWordIndex)
    }

    private func circleFill(isCompleted: Bool, isSkipped: Bool, isCurrent: Bool) -> Color {
        if isCompleted { return Color(hex: "#EAF3E3") }
        if isSkipped { return Color.gray.opacity(0.25) }
        if isCurrent { return Color(hex: "#FDF2D8") }
        return Color.gray.opacity(0.12)
    }

    // MARK: Helpers
    private func colorForWord(at index: Int) -> Color {
        if let glossUniformColor {
            return glossUniformColor
        }
        if completedWords.contains(index) {
            return .gray
        } else if skippedWords.contains(index) {
            return .gray.opacity(0.55)
        } else if index == currentWordIndex {
            return .black
        } else {
            return Color(hex: "#F0F0F0")
        }
    }

    /// Called by the camera view when confidence crosses the "good" threshold.
    /// Schedules an auto-advance shortly after the first pass.
    private func handleThresholdReached(confidence: Double) {
        guard !isFinished else { return }

        // Track max score after passing threshold
        if passedThreshold {
            currentWordMaxScore = max(currentWordMaxScore, confidence)
            return
        }

        passedThreshold = true
        currentWordMaxScore = confidence
        flashCorrectCheckmark()

        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: autoAdvanceDelay)
            if Task.isCancelled { return }
            if passedThreshold && !isFinished {
                advanceWord()
            }
        }
    }

    private func advanceWord() {
        advance(markingCurrentAs: .completed)
    }

    private func skipWord() {
        advance(markingCurrentAs: .skipped)
    }

    private enum WordOutcome { case completed, skipped }

    private func advance(markingCurrentAs outcome: WordOutcome) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        correctCheckmarkTask?.cancel()
        correctCheckmarkTask = nil
        showCorrectCheckmark = false

        guard currentWordIndex < glossWords.count else {
            if isFinished { finalizeAndComplete() }
            return
        }

        withAnimation {
            switch outcome {
            case .completed:
                completedWords.insert(currentWordIndex)
                // In simulator without real detection, give a default good score
                let score = currentWordMaxScore > 0 ? currentWordMaxScore : (isSimulator ? 85 : 0)
                wordMaxScores[currentWordIndex] = score
            case .skipped:
                skippedWords.insert(currentWordIndex)
                wordMaxScores[currentWordIndex] = Self.skippedWordRawScore
            }
            currentWordIndex += 1
        }

        // Reset threshold and max score for the next word (or leave false if finished).
        passedThreshold = false
        currentWordMaxScore = 0

        if isFinished {
            finalizeAndComplete()
        }
    }

    private func finalizeAndComplete() {
        externalCameraVM?.stopComparing()
        // Build array of word scores in order, then apply a user-facing
        // boost (capped 0…100) before persisting and averaging.
        let rawScores = (0..<glossWords.count).map { wordMaxScores[$0] ?? 0 }
        let scores = rawScores.map { Self.userFacingSigningScore(from: $0) }
        sentenceModel.wordScores = scores
        let average = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        sentenceModel.score = Int(average.rounded())
        onSentenceFinished?(average)
    }

    /// User-facing boost on raw per-word confidence (0–100), still capped at 100.
    private static func userFacingSigningScore(from raw: Double) -> Double {
        min(100, raw * 1.3)
    }

    /// Raw score that becomes exactly 50 after inflation.
    private static let skippedWordRawScore: Double = 50.0 / 1.3

    private func flashCorrectCheckmark() {
        correctCheckmarkTask?.cancel()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            showCorrectCheckmark = true
        }
        correctCheckmarkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.18)) {
                showCorrectCheckmark = false
            }
        }
    }
}

private struct SigningCorrectCheckmarkOverlay: View {
    var body: some View {
        Circle()
            .fill(Color(hex: "#EAF3E3").opacity(0.95))
            .frame(width: 160, height: 160)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 82, weight: .semibold))
                    .foregroundColor(Color(hex: "#71A046"))
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            .allowsHitTesting(false)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
