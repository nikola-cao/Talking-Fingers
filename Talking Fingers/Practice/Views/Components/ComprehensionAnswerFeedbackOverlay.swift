//
//  ComprehensionAnswerFeedbackOverlay.swift
//  Talking Fingers
//
//  Bottom sheet shown after submitting sentence comprehension (correct / incorrect).
//  Styling aligns with SentenceCompletionOverlay / signing flow.
//

import SwiftUI

struct ComprehensionAnswerFeedbackOverlay: View {
    let isCorrect: Bool
    let answerPhrase: String
    var onContinue: () -> Void

    private var textAccent: Color {
        isCorrect ? TFColors.deepGreen : TFColors.alertRed
    }

    private var continueButtonColor: Color {
        isCorrect ? TFColors.green : TFColors.red
    }

    private var overlayBackground: Color {
        isCorrect ? TFColors.paleGreen : TFColors.paleRed
    }

    private var titleText: String {
        isCorrect ? "Amazing!" : "Not quite!"
    }

    var body: some View {
        BottomFeedbackOverlay(
            isPositive: isCorrect,
            title: titleText,
            textAccent: textAccent,
            buttonColor: continueButtonColor,
            background: overlayBackground,
            onContinue: onContinue
        ) {
            (Text("Answer: ").font(.jakarta(size: 17, weight: .semibold)) + Text(answerPhrase).font(.jakarta(size: 17, weight: .regular)))
                .foregroundColor(textAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
