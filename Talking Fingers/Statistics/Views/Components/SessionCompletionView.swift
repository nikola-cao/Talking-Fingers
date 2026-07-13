//
//  SessionCompletionView.swift
//  Talking Fingers
//
//  End-of-session results screen: large score ring, per-category accuracy
//  bars (computed from the session's completed sentences), and
//  Extend / Finish actions.
//

import SwiftUI

struct SessionCompletionView: View {
    let sentences: [AISentenceModel]
    /// Categories to show accuracy bars for; falls back to the categories
    /// present in the session's gloss, then to a single overall row.
    let displayCategories: [TermCategory]
    let isExtending: Bool
    let onExtend: () -> Void
    let onFinish: () -> Void

    /// Animated bar values (0…1) keyed by category raw value; climb from 0 on appear.
    @State private var animatedBarProgress: [String: Double] = [:]

    private let extendFill = Color(hex: "#D6ECC4")
    private let extendText = Color(hex: "#3D6B2A")
    private let finishGreen = TFColors.green

    private let accentHigh = TFColors.deepGreen
    private let accentMed = TFColors.amber
    private let accentLow = TFColors.red
    /// Fills only the large session score ring (softer than accent).
    private let scoreRingFillHigh = Color(hex: "#B1D094")
    private let scoreRingFillMed = Color(hex: "#FACD6B")
    private let scoreRingFillLow = Color(hex: "#FF6F71")
    private let gradientTopHigh = Color(hex: "#F0F6EA")
    private let gradientBottomHigh = Color(hex: "#FAFCF8")
    private let gradientTopMed = Color(hex: "#FFF5E0")
    private let gradientBottomMed = Color(hex: "#FFFCF5")
    private let gradientTopLow = Color(hex: "#FFE0E0")
    private let gradientBottomLow = Color(hex: "#FFF5F5")

    // MARK: Score tier (cutoffs: ≥80 / ≥60 / else)

    private enum ScoreTier {
        case high, medium, low

        init(accuracy: Double) {
            if accuracy >= 80 { self = .high }
            else if accuracy >= 60 { self = .medium }
            else { self = .low }
        }

        var bloomMessage: String {
            switch self {
            case .high: return "You're in full bloom!"
            case .medium: return "You're growing!"
            case .low: return "You're getting there!"
            }
        }

        var topMessage: String {
            switch self {
            case .high: return "Superb work!"
            case .medium: return "Solid stuff!"
            case .low: return "Room to improve!"
            }
        }
    }

    // MARK: Accuracy

    private var completedSentences: [AISentenceModel] {
        sentences.filter(\.completed)
    }

    private var sessionAccuracy: Double {
        let accuracies = completedSentences.compactMap(\.accuracy)
        guard !accuracies.isEmpty else { return 0 }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }

    /// Average accuracy (0…100) over completed sentences whose gloss touches `category`.
    private func accuracy(for category: TermCategory) -> Double {
        let accuracies = completedSentences
            .filter { sentence in sentence.gloss.contains { $0.category == category } }
            .compactMap(\.accuracy)
        guard !accuracies.isEmpty else { return 0 }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }

    /// Categories touched by gloss in this session (stable order).
    private var sessionCategories: [TermCategory] {
        let present = Set(completedSentences.flatMap { $0.gloss.map(\.category) })
        return TermCategory.allCases.filter { present.contains($0) }
    }

    /// One row per category; falls back to a single overall "Practice" row.
    private var barRowSpecs: [(key: String, title: String, accuracy: Double)] {
        let categories = !displayCategories.isEmpty ? displayCategories : sessionCategories
        if !categories.isEmpty {
            return categories.map { ($0.rawValue, $0.displayName, accuracy(for: $0)) }
        }
        return [("practice", "Practice", sessionAccuracy)]
    }

    private var tier: ScoreTier { ScoreTier(accuracy: sessionAccuracy) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            resultsCard
                .padding(.horizontal, 20)

            Spacer(minLength: 12)

            HStack(spacing: 14) {
                Button(action: onExtend) {
                    Text("Extend")
                        .font(.jakarta(size: 17, weight: .semibold))
                        .foregroundColor(extendText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(extendFill)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isExtending)

                Button(action: onFinish) {
                    Text("Finish")
                        .font(.jakarta(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(finishGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            runBarIntroAnimation()
        }
    }

    private var resultsCard: some View {
        let scoreInt = Int(min(100, max(0, sessionAccuracy.rounded())))

        return VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(scoreRingFill)
                        .frame(width: 180, height: 180)

                    VStack(spacing: 2) {
                        Text("\(scoreInt)")
                            .font(.jakarta(size: 76, weight: .semibold))
                            .foregroundColor(.white)
                        Text("of 100")
                            .font(.jakarta(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                    }
                }

                Text(tier.topMessage)
                    .font(.jakarta(size: 20, weight: .semibold))
                    .foregroundColor(tierAccent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background {
                LinearGradient(
                    colors: gradientPair,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 18) {
                Text(tier.bloomMessage)
                    .font(.jakarta(size: 20, weight: .semibold))
                    .foregroundColor(tierAccent)

                ForEach(barRowSpecs, id: \.key) { spec in
                    categoryRow(
                        title: spec.title,
                        progress: animatedBarProgress[spec.key] ?? 0
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TFColors.borderLight, lineWidth: 1.5)
        )
    }

    private func categoryRow(title: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.jakarta(size: 15, weight: .medium))
                .foregroundColor(TFColors.darkerGray)

            HStack(alignment: .center, spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(TFColors.barTrackBlue)
                            .frame(height: 8)
                        Capsule()
                            .fill(TFColors.blue)
                            .frame(width: max(6, CGFloat(progress) * geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                Image(systemName: "medal.fill")
                    .font(.jakarta(size: 18, weight: .medium))
                    .foregroundColor(TFColors.lightBlue)
                    .frame(width: 22, alignment: .center)
            }
        }
    }

    private func runBarIntroAnimation() {
        let specs = barRowSpecs
        let targets = Dictionary(uniqueKeysWithValues: specs.map { ($0.key, $0.accuracy / 100) })
        animatedBarProgress = Dictionary(uniqueKeysWithValues: specs.map { ($0.key, 0) })
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.05)) {
                animatedBarProgress = targets
            }
        }
    }

    // MARK: Tier styling

    private var tierAccent: Color {
        switch tier {
        case .high: return accentHigh
        case .medium: return accentMed
        case .low: return accentLow
        }
    }

    private var scoreRingFill: Color {
        switch tier {
        case .high: return scoreRingFillHigh
        case .medium: return scoreRingFillMed
        case .low: return scoreRingFillLow
        }
    }

    private var gradientPair: [Color] {
        switch tier {
        case .high: return [gradientTopHigh, gradientBottomHigh]
        case .medium: return [gradientTopMed, gradientBottomMed]
        case .low: return [gradientTopLow, gradientBottomLow]
        }
    }
}
