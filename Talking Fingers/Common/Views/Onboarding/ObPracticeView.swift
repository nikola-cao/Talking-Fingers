//
//  ObPracticeView.swift
//  Talking Fingers
//
//  Final onboarding page: fingerspell your own name with the camera,
//  advancing letter by letter as each sign passes the confidence threshold.
//

import SwiftUI

struct ObPracticeView: View {
    let onNext: () -> Void
    @State var name: String
    @State private var currentIndex: Int = 0
    @State private var isPassed: Bool = false
    @State private var finished = false
    @State private var completedWords: Set<Int> = []
    @State private var onboardingCameraVM = CameraVM()
    @State private var advanceTask: Task<Void, Never>?
    private let passThreshold: Double = 0.85

    var body: some View {
        let letters = Array(name.uppercased())
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Try fingerspelling your name!")
                    .font(.jakarta(size: 17, weight: .regular))
                    .foregroundColor(OnboardingStyle.textDark)
            }
            HStack(spacing: 8) {
                ForEach(letters.indices, id: \.self) { i in
                    Text(String(letters[i]))
                        .font(.jakarta(size: 32, weight: .semibold))
                        .foregroundColor(i == currentIndex ? OnboardingStyle.textDark : Color(hex: "#CCCCCC"))

                    if i != letters.count - 1 {
                        Text("-")
                            .font(.jakarta(size: 32, weight: .semibold))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                }
            }

            // Practice view for the current letter
            if currentIndex < letters.count {
                practiceView(letters: letters)
                nameProgressCircles
                    .padding(.bottom, 24)
            }
            if finished {
                OnboardingPrimaryButton(title: "Next", action: onNext)
                    .padding(.top, 8)
            }
        }
        .padding()
        #if os(macOS)
        .onAppear {
            onboardingCameraVM.isMirrored = true
            onboardingCameraVM.checkPermission()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            onboardingCameraVM.start()
        }
        #endif
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
            onboardingCameraVM.stop()
        }
    }

    @ViewBuilder
    private func practiceView(letters: [Character]) -> some View {
        let practice = SigningPracticeView(
            signName: String(letters[currentIndex]),
            onConfidenceChange: { score in
                if score >= passThreshold && !isPassed {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPassed = true
                        completedWords.insert(currentIndex)
                    }
                    advanceTask?.cancel()
                    advanceTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        if Task.isCancelled { return }
                        isPassed = false
                        completedWords.insert(currentIndex)
                        if currentIndex < letters.count - 1 {
                            currentIndex += 1
                        } else {
                            finished = true
                        }
                    }
                }
            },
            showsLeaveButton: false,
            usesInternalPadding: false,
            externalCameraVM: onboardingCameraVM
        )

        #if os(iOS)
        practice
            .frame(maxWidth: .infinity)
            .frame(height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        #else
        practice
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        #endif
    }

    private var nameProgressCircles: some View {
        let letters = Array(name.uppercased())
        return Group {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(letters.enumerated()), id: \.offset) { index, _ in
                                circleIcon(for: index)
                                    .id("circle-\(index)")
                            }
                        }
                        .frame(minWidth: geometry.size.width, alignment: .center)
                    }
                    .onChange(of: currentIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("circle-\(newIndex)", anchor: .center)
                        }
                    }
                }
            }
            .frame(height: Self.progressCircleColumnWidth + 26)
        }
    }

    private static let progressCircleColumnWidth: CGFloat = 72
    private static let progressCircleDiameter: CGFloat = 52

    @ViewBuilder
    private func circleIcon(for index: Int) -> some View {
        let letters = Array(name.uppercased())
        let isCompleted = completedWords.contains(index)
        let isCurrent = index == currentIndex && !finished
        let wordLabel = index < letters.count ? String(letters[index]) : ""
        let d = Self.progressCircleDiameter

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(circleFill(isCompleted: isCompleted, isCurrent: isCurrent))
                    .frame(width: isCurrent ? d + 10 : d, height: isCurrent ? d + 10 : d)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#71A046"))
                } else if isCurrent {
                    Image(systemName: "lightbulb.max")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(TFColors.gold)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#B3B3B3"))
                }
            }
            .frame(width: Self.progressCircleColumnWidth, height: Self.progressCircleColumnWidth, alignment: .center)

            Text(wordLabel)
                .font(.jakarta(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "#767676"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(isCurrent ? 1 : 0)
                .frame(height: 20)
        }
        .frame(width: Self.progressCircleColumnWidth)
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }

    private func circleFill(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted { return TFColors.paleGreen }
        if isCurrent { return TFColors.paleGold }
        return Color.gray.opacity(0.12)
    }
}
