//
//  OnboardingComponents.swift
//  Talking Fingers
//
//  Pieces shared by the onboarding pages: the welcome gradient backdrop,
//  the green pill button, the handedness picker card, and the ASL sign
//  descriptions used on the fingerspelling page.
//

import SwiftUI

enum OnboardingStyle {
    static let contentWidth: CGFloat = 338
    static let textDark = Color(hex: "#464646")
    static let border = Color(hex: "#E2E2E2")
}

/// Pale green backdrop with the two blurred radial gradients from the welcome page.
struct WelcomeGradientBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .ignoresSafeArea()
                .foregroundColor(TFColors.paleGreen)

            RadialGradient(colors: [Color(hex: "#82C8FF"), TFColors.practiceGreen], center: .center, startRadius: 0, endRadius: 250)
                .frame(width: 500, height: 500)
                .clipShape(Circle())
                .blur(radius: 200)
                .offset(x: -160, y: -400)

            RadialGradient(colors: [TFColors.gold, TFColors.practiceGreen], center: .center, startRadius: 0, endRadius: 250)
                .frame(width: 500, height: 500)
                .clipShape(Circle())
                .blur(radius: 200)
                .offset(x: 160, y: 400)
        }
    }
}

/// The green pill CTA used on every onboarding page. Dims and disables
/// itself while `disabled` is true.
struct OnboardingPrimaryButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 100)
                    .foregroundColor(TFColors.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 45)
                Text(title)
                    .font(.jakarta(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                if disabled {
                    RoundedRectangle(cornerRadius: 100)
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .frame(maxWidth: OnboardingStyle.contentWidth)
    }
}

/// Left/right dominant-hand picker card.
struct SelectHandButton: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .frame(maxWidth: .infinity)
                    .frame(height: 181)
                    .foregroundColor(isSelected ? TFColors.paleGold : Color(hex: "#FCFCFC"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(OnboardingStyle.border, lineWidth: 1)
                    )
                VStack {
                    Image(imageName)
                    Text(title)
                        .font(.jakarta(size: 20, weight: .regular))
                        .foregroundColor(OnboardingStyle.textDark)
                }
            }
        }
        .frame(maxWidth: 165)
        .buttonStyle(.plain)
    }
}

enum ASLSignDescriptions {
    static let byLetter: [Character: String] = [
        "a": "Fist with thumb on side",
        "b": "Open hand, thumb across palm",
        "c": "C-shaped curve",
        "d": "Index up, thumb touches middle finger",
        "e": "Fingers curled into palm",
        "f": "Index + thumb touch (circle)",
        "g": "Sideways point with index",
        "h": "Index + middle together, horizontal",
        "i": "Pinky finger up",
        "j": "Trace J shape with pinky",
        "k": "V shape with index + thumb",
        "l": "L shape with thumb + index",
        "m": "Thumb under three fingers",
        "n": "Thumb under two fingers",
        "o": "Fingers form a circle",
        "p": "Thumb and middle touching, pointer pointing down",
        "q": "Pointer curled + middle and thumb pointing down",
        "r": "Index + middle crossed",
        "s": "Fist with thumb over fingers",
        "t": "Thumb between fingers",
        "u": "Index + middle up together",
        "v": "V shape fingers",
        "w": "Three fingers up",
        "x": "Hooked index finger",
        "y": "Thumb + pinky extended",
        "z": "Trace Z in air"
    ]

    static func description(for letter: Character) -> String {
        byLetter[letter] ?? "No description available"
    }
}
