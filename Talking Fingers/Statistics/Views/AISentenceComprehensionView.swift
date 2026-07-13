//
//  AISentenceComprehensionView.swift
//  Talking Fingers
//
//  Created by Jagat Sachdeva on 2/23/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AISentenceComprehensionView: View {
    @Binding var sentenceModel: AISentenceModel
    var onSentenceComplete: (() -> Void)? = nil

    private var correctOrder: [String] {
        sentenceModel.gloss.map { $0.rawValue.lowercased() }
    }

    @State private var allChips: [CompWordChip] = []
    @State private var lineChips: [CompWordChip] = []
    @State private var submitState: CompSubmitState = .idle
    @State private var totalAttemptCount: Int = 0
    @State private var macCarouselIndex: Int = 0
    #if os(macOS)
    @State private var macKeyMonitor: Any?
    #endif

    private let chipTextColor = TFColors.darkerGray
    private let chipBorderColor = TFColors.borderLight
    private let chipPlaceholderColor = TFColors.paleGold

    private var glossTerms: [Term] { sentenceModel.gloss }

    private var canSubmitAnswer: Bool { lineChips.count == correctOrder.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: 0)

                signImagesGrid

                answerArea

                wordBankView

                Spacer(minLength: 0)

                if submitState == .idle {
                    actionButton(
                        title: "Submit",
                        foreground: .white,
                        background: TFColors.green
                    ) { submit() }
                    .opacity(canSubmitAnswer ? 1.0 : 0.5)
                    .disabled(!canSubmitAnswer)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
            .allowsHitTesting(submitState == .idle)

            if submitState != .idle {
                ComprehensionAnswerFeedbackOverlay(
                    isCorrect: submitState == .correct,
                    answerPhrase: correctOrder.joined(separator: " "),
                    onContinue: { onSentenceComplete?() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: submitState)
        .onAppear { setupChips() }
        #if os(macOS)
        .onAppear {
            installMacCarouselKeyMonitor()
        }
        .onDisappear {
            removeMacCarouselKeyMonitor()
        }
        #endif
    }

    // MARK: - Sign Images Grid

    private var signImagesGrid: some View {
#if os(macOS)
        VStack(spacing: 10) {
            if !glossTerms.isEmpty {
                signPlaceholderCard(for: glossTerms[clampedMacCarouselIndex])
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(height: 300)
            }

            HStack(spacing: 10) {
                Button {
                    moveMacCarousel(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.jakarta(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(TFColors.green)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(clampedMacCarouselIndex == 0)
                .opacity(clampedMacCarouselIndex == 0 ? 0.4 : 1)

                HStack(spacing: 6) {
                    ForEach(Array(glossTerms.enumerated()), id: \.offset) { index, _ in
                        Circle()
                            .fill(index == clampedMacCarouselIndex ? TFColors.green : Color.gray.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Button {
                    moveMacCarousel(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.jakarta(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(TFColors.green)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(clampedMacCarouselIndex == max(glossTerms.count - 1, 0))
                .opacity(clampedMacCarouselIndex == max(glossTerms.count - 1, 0) ? 0.4 : 1)
            }
        }
        .padding(.bottom, 4)
#else
        TabView {
            ForEach(Array(glossTerms.enumerated()), id: \.offset) { _, term in
                signPlaceholderCard(for: term)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 180)
        .padding(.bottom, 4)
#endif
    }

    private var clampedMacCarouselIndex: Int {
        guard !glossTerms.isEmpty else { return 0 }
        return min(max(0, macCarouselIndex), glossTerms.count - 1)
    }

    private func moveMacCarousel(by offset: Int) {
        guard !glossTerms.isEmpty else { return }
        let nextIndex = clampedMacCarouselIndex + offset
        macCarouselIndex = min(max(0, nextIndex), glossTerms.count - 1)
    }

#if os(macOS)
    private func installMacCarouselKeyMonitor() {
        guard macKeyMonitor == nil else { return }
        macKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard NSApp.isActive else { return event }

            switch event.keyCode {
            case 123: // Left arrow
                moveMacCarousel(by: -1)
                return nil
            case 124: // Right arrow
                moveMacCarousel(by: 1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeMacCarouselKeyMonitor() {
        guard let macKeyMonitor else { return }
        NSEvent.removeMonitor(macKeyMonitor)
        self.macKeyMonitor = nil
    }
#endif
    
    private func signPlaceholderCard(for term: Term) -> some View {
        Group {
            if let gifFileName = term.defaultGifFileName {
                GIFView(gifFileName: gifFileName)
                    .id(gifFileName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "person.fill")
                        .font(.jakarta(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No GIF")
                        .font(.jakarta(size: 9))
                        .foregroundColor(.gray.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Answer Area (bordered box — red/green/gray border)

    private var answerArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(verticalSpacing: 10, horizontalSpacing: 10) {
                ForEach(lineChips) { chip in
                    chipView(
                        chip.text,
                        background: .white,
                        borderColor: answerChipBorderColor,
                        foregroundColor: answerChipForegroundColor
                    )
                    .onTapGesture {
                        guard submitState == .idle else { return }
                        withAnimation(.spring()) {
                            lineChips.removeAll { $0.id == chip.id }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 52)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(answerBorderColor, lineWidth: submitState == .idle ? 1 : 2)
        )
    }

    private var answerBorderColor: Color {
        switch submitState {
        case .correct:
            return TFColors.paleGreen
        case .incorrect:
            return TFColors.paleRed
        case .idle:
            return Color.gray.opacity(0.35)
        }
    }

    private var answerChipBorderColor: Color {
        switch submitState {
        case .idle:
            return chipBorderColor
        case .correct:
            return Color(hex: "#689F38")
        case .incorrect:
            return Color(hex: "#E53935")
        }
    }

    private var answerChipForegroundColor: Color {
        submitState == .idle ? chipTextColor : answerChipBorderColor
    }

    // MARK: - Word Bank

    private var wordBankView: some View {
        FlowLayout(verticalSpacing: 10, horizontalSpacing: 10, alignment: .center) {
            ForEach(allChips) { chip in
                if lineChips.contains(where: { $0.id == chip.id }) {
                    // Shadow placeholder
                    Text(chip.text)
                        .font(.jakarta(size: 17))
                        .foregroundColor(chipTextColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .opacity(0)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .frame(minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(chipPlaceholderColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(chipBorderColor, lineWidth: 1.5)
                        )
                } else {
                    chipView(chip.text, background: .white, borderColor: chipBorderColor, foregroundColor: chipTextColor)
                        .onTapGesture {
                            guard submitState == .idle else { return }
                            withAnimation(.spring()) {
                                lineChips.append(chip)
                            }
                        }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Chip

    private func chipView(
        _ text: String,
        background: Color,
        borderColor: Color,
        foregroundColor: Color
    ) -> some View {
        Text(text)
            .font(.jakarta(size: 17))
            .foregroundColor(foregroundColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(minHeight: 40)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1.5)
            )
    }

    // MARK: - Logic

    private func setupChips() {
        let correctSet = Set(correctOrder)
        let allTermStrings = Term.allCases.map { $0.rawValue.lowercased() }
        let possibleDistractors = allTermStrings.filter { !correctSet.contains($0) }
        let numDistractors = max(0, 7 - correctOrder.count)
        let distractors = Array(possibleDistractors.shuffled().prefix(numDistractors))

        let allWords = (correctOrder + distractors).shuffled()
        allChips = allWords.map { CompWordChip(text: $0) }
        lineChips = []
        submitState = .idle
        totalAttemptCount = 0
        macCarouselIndex = 0
    }

    private func submit() {
        guard lineChips.count == correctOrder.count else { return }

        totalAttemptCount += 1
        let userAnswer = lineChips.map { $0.text }
        let isCorrect = userAnswer == correctOrder
        sentenceModel.comprehensionAttempts = totalAttemptCount
        sentenceModel.comprehensionWasCorrect = isCorrect
        if isCorrect {
            withAnimation { submitState = .correct }
        } else {
            withAnimation { submitState = .incorrect }
        }
    }

    private func actionButton(
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(background)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

private enum CompSubmitState: Equatable {
    case idle
    case correct
    case incorrect
}

private struct CompWordChip: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

#Preview {
    @Previewable @State var sampleModel = AISentenceModel(
        sentence: "Today was good, thank you.",
        practiceType: .comprehension,
        gloss: [.today, .good, .happy, .you]
    )
    
    AISentenceComprehensionView(
        sentenceModel: $sampleModel
    )
}
