//
//  ExerciseSettingsMenu.swift
//  Talking Fingers
//

import SwiftUI

/// Top-bar menu that lets the user toggle Flashcard and/or Camera exercise modes mid-session.
/// Both options can be active simultaneously (`.mixed` mode).
struct ExerciseSettingsMenu: View {
    @Binding var mode: ExerciseInputMode

    var body: some View {
        Menu {
            Button {
                toggleFlashcards()
            } label: {
                Label(
                    "Flashcards",
                    systemImage: flashcardsSelected ? "checkmark" : "rectangle.stack"
                )
            }

            Button {
                toggleCamera()
            } label: {
                Label(
                    "Camera",
                    systemImage: cameraSelected ? "checkmark" : "camera"
                )
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.jakarta(size: 18, weight: .medium))
                .foregroundColor(.black)
        }
        .menuOrder(.fixed)
    }

    // MARK: - Helpers

    private var flashcardsSelected: Bool {
        mode == .flashcards || mode == .mixed
    }

    private var cameraSelected: Bool {
        mode == .camera || mode == .mixed
    }

    private func toggleFlashcards() {
        switch mode {
        case .flashcards: break        // already the only active option — keep it
        case .camera:     mode = .mixed
        case .mixed:      mode = .camera
        }
    }

    private func toggleCamera() {
        switch mode {
        case .camera:     break        // already the only active option — keep it
        case .flashcards: mode = .mixed
        case .mixed:      mode = .flashcards
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ExerciseSettingsMenu(mode: .constant(.flashcards))
        ExerciseSettingsMenu(mode: .constant(.camera))
        ExerciseSettingsMenu(mode: .constant(.mixed))
    }
    .padding()
}
