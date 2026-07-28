//
//  SessionTopBar.swift
//  Talking Fingers
//
//  Progress bar + Leave button shared by every exercise / learn screen
//  (VisionExerciseView, LearnModeView, SearchView practice flow).
//

import SwiftUI

/// Progress bar + Leave button shared by every exercise / learn screen.
/// Pass a `@ViewBuilder` trailing block to add items (e.g. `ExerciseSettingsMenu`)
/// next to the progress bar; omit it for just the bar.
struct SessionTopBar<Trailing: View>: View {
    var progress: Double
    var onLeave: () -> Void
    private let trailing: Trailing

    init(
        progress: Double,
        onLeave: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.progress = progress
        self.onLeave = onLeave
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { onLeave() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.jakarta(size: 16, weight: .medium))
                        Text("Leave")
                            .font(.jakarta(size: 16, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(TFColors.trackBlueLight)
                        Capsule()
                            .fill(TFColors.tabBlue)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 10)

                trailing
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 10)
    }
}

extension SessionTopBar where Trailing == EmptyView {
    init(progress: Double, onLeave: @escaping () -> Void) {
        self.init(progress: progress, onLeave: onLeave, trailing: { EmptyView() })
    }
}
