//
//  PracticeCards.swift
//  Talking Fingers
//
//  Cards used on the Practice screen: the Sign / Comprehend mode launchers
//  and the saved-practice ("My Practices") list rows.
//

import SwiftUI

// MARK: - Practice Mode Card

struct PracticeModeCard: View {
    let title: String
    let subtitle: String
    let tint: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let border: Color
    let imageAssetName: String
    let placeholderOnLeading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                if placeholderOnLeading {
                    imagePlaceholder
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.jakarta(size: 27, weight: .semibold))
                        .foregroundColor(tint)

                    #if os(iOS)
                    Text(subtitle)
                        .font(.jakarta(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.78))
                        .multilineTextAlignment(.leading)
                    #else
                    Text(subtitle)
                        .font(.jakarta(size: 17, weight: .medium))
                        .foregroundColor(.black.opacity(0.78))
                        .multilineTextAlignment(.leading)
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !placeholderOnLeading {
                    imagePlaceholder
                }
            }
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [backgroundTop, backgroundBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var imagePlaceholder: some View {
        Image(imageAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 130, height: 130)
    }
}

// MARK: - Training Card

struct TrainingCard: View {
    enum ActionType {
        case continueSession
        case retry
    }

    let item: TrainingItem
    let isExpanded: Bool
    let onTapCard: () -> Void
    var onReview: () -> Void = {}
    var onRetry: () -> Void = {}
    var actionType: ActionType = .continueSession

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            HStack(alignment: .center, spacing: 14) {
                leftIcon

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.jakarta(size: 17, weight: .medium))
                            .foregroundColor(.black)
                        completionTag
                    }
                    Text(item.subtitle)
                        .font(.jakarta(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                }

                Spacer()
                accuracyCircle
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapCard()
            }

            if isExpanded {
                Button {
                    switch actionType {
                    case .continueSession:
                        onReview()
                    case .retry:
                        onRetry()
                    }
                } label: {
                    Text(actionType == .continueSession ? "Continue" : "Retry")
                        .font(.jakarta(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(hex: "#97C171"))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color(hex: "#DDDDDD"), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                onTapCard()
            }
        }
    }

    @ViewBuilder
    private var leftIcon: some View {
        Image(systemName: item.iconName)
            .font(.jakarta(size: 20, weight: .regular))
            .foregroundColor(Color(hex: "#FBDA92"))
            .frame(width: 28)
    }

    @ViewBuilder
    private var completionTag: some View {
        Text(item.isComplete ? "Complete" : "Incomplete")
            .font(.jakarta(size: 11, weight: .medium))
            .foregroundColor(item.isComplete ? Color(hex: "#4A7C3F") : Color.gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isComplete ? Color(hex: "#EAF3E3") : Color.gray.opacity(0.15))
            )
    }

    @ViewBuilder
    private var accuracyCircle: some View {
        if let accuracy = item.accuracy {
            ZStack {
                Circle()
                    .fill(item.accuracyColor)
                    .frame(width: 54, height: 54)

                Circle()
                    .stroke(item.accuracyBorderColor, lineWidth: 2)
                    .frame(width: 54, height: 54)

                Text("\(Int(accuracy.rounded()))")
                    .font(.jakarta(size: 17, weight: .semibold))
                    .foregroundColor(item.accuracyTextColor)
            }
        } else {
            InProgressCircleView(progress: item.completionProgress)
        }
    }
}

struct InProgressCircleView: View {
    var progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                .frame(width: 46, height: 46)

            Circle()
                .trim(from: 0, to: max(clampedProgress, 0.02))
                .stroke(
                    Color.gray,
                    style: StrokeStyle(lineWidth: 10, lineCap: .butt)
                )
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-90))
        }
    }
}

struct TrainingItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let accuracy: Double?
    let isComplete: Bool
    let completionProgress: Double
    let iconName: String

    var accuracyColor: Color {
        guard let acc = accuracy else { return Color.gray }
        if acc >= 80 { return Color(hex: "#EAF3E3") }
        if acc >= 60 { return Color(hex: "#FACD6B") }
        return Color(hex: "#FA6B6E")
    }

    var accuracyTextColor: Color {
        guard let acc = accuracy else { return Color.gray }
        if acc >= 80 { return Color(hex: "#4A7C3F") }
        if acc >= 60 { return Color(hex: "#8B6914") }
        return Color(hex: "#A13B3D")
    }

    var accuracyBorderColor: Color {
        guard let acc = accuracy else { return Color.gray.opacity(0.75) }
        if acc >= 80 { return Color(hex: "#A8D4A0") }
        if acc >= 60 { return Color(hex: "#E5B84A") }
        return Color(hex: "#E55558")
    }
}
