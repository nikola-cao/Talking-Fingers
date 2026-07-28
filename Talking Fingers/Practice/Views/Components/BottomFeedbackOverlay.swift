//
//  BottomFeedbackOverlay.swift
//  Talking Fingers
//
//  Shared chrome for the bottom feedback overlays shown after a practice
//  answer/sentence: rounded bottom sheet on iOS, centered banner on macOS.
//  The middle line (accuracy / answer text) is supplied by the caller.
//

import SwiftUI

struct BottomFeedbackOverlay<Middle: View>: View {
    /// Drives the leading icon: checkmark when positive, xmark otherwise.
    let isPositive: Bool
    let title: String
    let textAccent: Color
    let buttonColor: Color
    let background: Color
    var onContinue: () -> Void
    @ViewBuilder var middle: () -> Middle

    var body: some View {
        #if os(macOS)
        macBanner
        #else
        iosSheet
        #endif
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.jakarta(size: 24, weight: .semibold))
                Text(title)
                    .font(.jakarta(size: 24, weight: .semibold))
            }
            .foregroundColor(textAccent)

            middle()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.jakarta(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonColor)
                    .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
    }

    private var iosSheet: some View {
        overlayContent
        .padding(.horizontal, 16)
        .padding(.top, 16)
        // Inset content from the home indicator; the fill extends under it (see below).
        .safeAreaPadding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .bottom) {
            background
                .ignoresSafeArea(edges: .bottom)

            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 26,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: 26
                ),
                style: .continuous
            )
            .fill(background)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    #if os(macOS)
    private var macBanner: some View {
        overlayContent
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 0)
            .frame(maxWidth: 760, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
    }
    #endif
}
