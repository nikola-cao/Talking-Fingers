//
//  ResultPopUps.swift
//  Talking Fingers
//
//  Correct/incorrect answer popups shown after submitting a
//  multiple-choice answer.
//

import SwiftUI

struct CorrectResultPopUpComponent: View {
    var message: String
    var onNext: () -> Void

    var body: some View {
        ResultCard(
            title: "Great Job!",
            isCorrect: true,
            message: message,
            onNext: onNext
        )
    }
}

struct IncorrectResultPopUpComponent: View {
    var message: String
    var onNext: () -> Void

    var body: some View {
        ResultCard(
            title: "Not Quite...",
            isCorrect: false,
            message: message,
            onNext: onNext
        )
    }
}

struct ResultCard: View {
    let title: String
    let isCorrect: Bool
    let message: String
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // TITLE ROW
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)

                Text(isCorrect ? "Amazing!" : "Not quite!")
                    .font(.jakarta(size: 24, weight: .bold))
                    .foregroundColor(isCorrect ? Color.green : Color.red)
            }

            Text(message)
                .foregroundColor(isCorrect ? Color.green : Color.red)
                .font(.jakarta(size: 16, weight: .medium))

            // BUTTON
            Button {
                onNext()
            } label: {
                Text("Continue")
                    .font(.jakartaHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isCorrect
                                  ? TFColors.lightGreen
                                  : Color.red.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 1100)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isCorrect
                      ? Color(red: 0.90, green: 0.95, blue: 0.85)
                      : Color(red: 0.95, green: 0.85, blue: 0.85))
        )
        .padding(.horizontal, 20)
    }
}
