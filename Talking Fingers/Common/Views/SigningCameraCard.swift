//
//  SigningCameraCard.swift
//  Talking Fingers
//
//  Live-camera signing card shared by VisionExerciseView and LearnModeView.
//

import SwiftUI

/// Reusable camera card used by both VisionExerciseView (all buttons shown) and
/// LearnModeView (save + stuck hidden). Pass showSaveButton/showStuckButton = false
/// to suppress the corresponding action button.
struct SigningCameraCard: View {
    let word: String
    var showSaveButton: Bool = true
    var showStuckButton: Bool = true
    var showSkipButton: Bool = false
    var showWordTitle: Bool = true
    /// Fixed height for the live camera feed. Pass nil to fill available space.
    var cameraHeight: CGFloat? = nil
    var isHintActive: Bool = false
    var isStuckActive: Bool = false
    var onConfidenceChange: (Double) -> Void = { _ in }
    var onHintTap: () -> Void = {}
    var onStuckTap: () -> Void = {}
    var onSkipTap: () -> Void = {}

    @State private var isSaved: Bool = false

    private let tfGreen     = TFColors.tfGreen
    private let tfGreenText = TFColors.tfGreenText
    private let circleSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 16) {
            if showWordTitle {
                Text(word)
                    .font(.jakarta(size: 45, weight: .bold))
                    .padding(.top, 4)
            }

            SigningPracticeView(signName: word, onConfidenceChange: onConfidenceChange)
                .frame(
                    maxWidth: .infinity,
                    minHeight: cameraHeight,
                    maxHeight: cameraHeight ?? .infinity
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 10) {
                        if showSaveButton {
                            Button { isSaved.toggle() } label: {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(tfGreenText)
                                    .frame(width: circleSize, height: circleSize)
                                    .background(Circle().fill(tfGreen.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                        }

                        Button { onHintTap() } label: {
                            Image(systemName: isHintActive ? "lightbulb.max.fill" : "lightbulb.max")
                                .foregroundColor(.orange)
                                .frame(width: circleSize, height: circleSize)
                                .background(Circle().fill(Color.orange.opacity(isHintActive ? 0.3 : 0.2)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if showStuckButton {
                        Button { onStuckTap() } label: {
                            Image(systemName: "exclamationmark")
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .frame(width: circleSize, height: circleSize)
                                .background(Circle().fill(Color.orange.opacity(isStuckActive ? 0.3 : 0.15)))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showSkipButton {
                        Button { onSkipTap() } label: {
                            Text("Skip word")
                                .font(.jakarta(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(TFColors.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }
        }
        .padding(20)
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
}
