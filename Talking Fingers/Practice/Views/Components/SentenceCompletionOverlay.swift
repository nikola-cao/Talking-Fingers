import SwiftUI

struct SentenceCompletionOverlay: View {
    let averageScore: Double
    var onContinue: () -> Void

    private var roundedScore: Int { Int(averageScore.rounded()) }

    private enum CompletionTier {
        case high
        case medium
        case low

        init(score: Int) {
            if score >= 75 {
                self = .high
            } else if score >= 50 {
                self = .medium
            } else {
                self = .low
            }
        }

        var textAccent: Color {
            switch self {
            case .high: return TFColors.deepGreen
            case .medium: return TFColors.amber
            case .low: return TFColors.alertRed
            }
        }

        var buttonAndGloss: Color {
            switch self {
            case .high: return TFColors.green
            case .medium: return TFColors.amber
            case .low: return TFColors.red
            }
        }

        var background: Color {
            switch self {
            case .high: return TFColors.paleGreen
            case .medium: return TFColors.cream
            case .low: return TFColors.paleRed
            }
        }

        var title: String {
            switch self {
            case .high: return "Amazing!"
            case .medium: return "Almost!"
            case .low: return "Not Quite!"
            }
        }
    }

    /// Continue button and live gloss row only (separate from overlay copy color).
    static func glossAndButtonColor(for averageScore: Double) -> Color {
        CompletionTier(score: Int(averageScore.rounded())).buttonAndGloss
    }

    private var tier: CompletionTier { CompletionTier(score: roundedScore) }

    private var textAccent: Color { tier.textAccent }
    private var continueButtonColor: Color { tier.buttonAndGloss }
    private var overlayBackground: Color { tier.background }
    private var titleText: String { tier.title }

    var body: some View {
        BottomFeedbackOverlay(
            isPositive: roundedScore >= 75,
            title: titleText,
            textAccent: textAccent,
            buttonColor: continueButtonColor,
            background: overlayBackground,
            onContinue: onContinue
        ) {
            Text("Accuracy: \(roundedScore)%")
                .font(.jakarta(size: 17, weight: .regular))
                .foregroundColor(textAccent)
        }
    }
}
