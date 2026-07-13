//
//  PracticeSessionView.swift
//  Talking Fingers
//
//  Session that runs AISentenceSigningView for each sentence, then shows
//  completion screen with Extend (add 5 more) / Finish (return to Saved Practice).
//

import SwiftUI

struct PracticeSessionView: View {
    @Binding var sentences: [AISentenceModel]
    var practiceTitle: String
    var selectedCategories: Set<TermCategory>?
    var isExistingSavedPractice: Bool = false
    var onFinish: (_ shouldSave: Bool) -> Void
    var onExtend: () async -> Void

    @State private var currentSentenceIndex: Int
    @State private var isExtending: Bool = false
    @State private var isLeaving: Bool = false
    @State private var showLeaveConfirmation: Bool = false
    @State private var showPracticeEntry: Bool = true
    @State private var signingSubtitle: String = "New sentence!"
    @State private var signingPageIndex: Int = 1
    @State private var showSigningSentenceCompletionOverlay: Bool = false
    @State private var signingSentenceAverageScore: Double = 0
    @State private var isSigningSentenceFavorited: Bool = false

    /// Shared camera VM kept alive for the whole session so sentence changes
    /// don't tear the AVCaptureSession down and build a new one (which was
    /// causing visible lag on the camera feed + overlay after the first
    /// sentence transition).
    @State private var sessionCameraVM = CameraVM()

    private let barBlue = Color(hex: "#58A0DA")
    private let barTrack = Color(hex: "#A9CEEC26")
    private let finishGreen = Color(hex: "#97C171")
    private let subtitleBlue = Color(hex: "#2A7BBC")

    init(
        sentences: Binding<[AISentenceModel]>,
        practiceTitle: String = "Practice",
        selectedCategories: Set<TermCategory>? = nil,
        initialSentenceIndex: Int = 0,
        isExistingSavedPractice: Bool = false,
        onFinish: @escaping (_ shouldSave: Bool) -> Void,
        onExtend: @escaping () async -> Void
    ) {
        self._sentences = sentences
        self.practiceTitle = practiceTitle
        self.selectedCategories = selectedCategories
        self.isExistingSavedPractice = isExistingSavedPractice
        self.onFinish = onFinish
        self.onExtend = onExtend
        let count = sentences.wrappedValue.count
        let clamped = min(max(0, initialSentenceIndex), count)
        self._currentSentenceIndex = State(initialValue: clamped)
    }

    private var sessionProgress: Double {
        guard !sentences.isEmpty else { return 0 }
        return Double(currentSentenceIndex) / Double(sentences.count)
    }

    /// Categories touched by gloss in this session (stable order).
    private var sessionCategories: [TermCategory] {
        let present = Set(sentences.flatMap { $0.gloss.map(\.category) })
        return TermCategory.allCases.filter { present.contains($0) }
    }

    private var displayCategories: [TermCategory] {
        if let selectedCategories, !selectedCategories.isEmpty {
            return TermCategory.allCases.filter { selectedCategories.contains($0) }
        }
        return sessionCategories
    }

    private var overallSessionProgress: Double {
        guard !sentences.isEmpty else { return 0 }
        return Double(sentences.filter(\.completed).count) / Double(sentences.count)
    }

    private var remainingSentenceCount: Int {
        max(0, sentences.count - currentSentenceIndex)
    }

    private var entryModeIsComprehension: Bool {
        guard currentSentenceIndex < sentences.count else {
            return sentences.allSatisfy { $0.practiceType == .comprehension } && !sentences.isEmpty
        }
        return sentences[currentSentenceIndex].practiceType == .comprehension
    }

    private var entryFlowerAssetName: String {
        entryModeIsComprehension ? "SentencesComprehendFlowerFull" : "SentencesSignFlowerFull"
    }

    private var currentTopProgress: Double {
        if showPracticeEntry { return overallSessionProgress }
        if currentSentenceIndex < sentences.count {
            return min(1, sessionProgress + 0.03)
        }
        return 1
    }

    private var currentTopSubtitle: String {
        if showPracticeEntry { return "Here we go!" }
        if currentSentenceIndex >= sentences.count { return "Practice completed!" }
        if sentences[currentSentenceIndex].practiceType == .comprehension { return "New sentence!" }
        if signingPageIndex == 2 { return "" }
        return signingSubtitle
    }

    private var currentTopSubtitleColor: Color { subtitleBlue }

    /// Hide the session bar while on the live camera / per-word signing step;
    /// it returns on the sentence intro + gloss page (page 1) for the next sentence.
    private var shouldShowSessionProgressBar: Bool {
        if showPracticeEntry { return true }
        guard currentSentenceIndex < sentences.count else { return true }
        if sentences[currentSentenceIndex].practiceType == .comprehension { return true }
        return signingPageIndex != 2
    }

    private var primaryActionButtonTitle: String? {
        if showPracticeEntry { return "Start" }
        guard currentSentenceIndex < sentences.count else { return nil }
        let currentSentence = sentences[currentSentenceIndex]
        if currentSentence.practiceType != .comprehension && signingPageIndex == 1 {
            return "Continue"
        }
        return nil
    }

    private func markCurrentSentenceCompletedAndAdvance() {
        withAnimation {
            if sentences.indices.contains(currentSentenceIndex) {
                var updated = sentences
                updated[currentSentenceIndex].completed = true
                sentences = updated
            }
            currentSentenceIndex += 1
            signingPageIndex = 1
            showSigningSentenceCompletionOverlay = false
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        if isExistingSavedPractice {
                            isLeaving = true
                            onFinish(true)
                        } else {
                            showLeaveConfirmation = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "door.left.hand.open")
                                .font(.jakarta(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#B3B3B3"))
                            Text("Leave")
                                .foregroundColor(Color(hex: "#B3B3B3"))
                                .font(.jakarta(size: 16, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Practice: \(practiceTitle)")
                        .font(.jakarta(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#B3B3B3"))
                }
                .padding(.horizontal, 24)
                #if os(macOS)
                .padding(.top, 60)
                .padding(.bottom, 8)
                #else
                .padding(.top, 30)
                .padding(.bottom, 4)
                #endif

                sessionTopChrome

                if showPracticeEntry {
                    PracticeEntryView(
                        practiceTitle: practiceTitle,
                        remainingSentenceCount: remainingSentenceCount,
                        categories: displayCategories,
                        flowerAssetName: entryFlowerAssetName
                    )
                } else if currentSentenceIndex < sentences.count {
                    if sentences[currentSentenceIndex].practiceType == .comprehension {
                        AISentenceComprehensionView(
                            sentenceModel: $sentences[currentSentenceIndex],
                            onSentenceComplete: {
                                markCurrentSentenceCompletedAndAdvance()
                            }
                        )
                        .id(currentSentenceIndex)
                    } else {
                        AISentenceSigningView(
                            sentenceModel: $sentences[currentSentenceIndex],
                            currentPage: $signingPageIndex,
                            onSentenceFinished: { average in
                                signingSentenceAverageScore = average
                                isSigningSentenceFavorited = false
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSigningSentenceCompletionOverlay = true
                                }
                            },
                            onSubtitleChange: { subtitle in
                                signingSubtitle = subtitle
                            },
                            glossUniformColor: showSigningSentenceCompletionOverlay
                                ? SentenceCompletionOverlay.glossAndButtonColor(for: signingSentenceAverageScore)
                                : nil,
                            externalCameraVM: sessionCameraVM
                        )
                        .id(currentSentenceIndex)
                    }
                } else if !isLeaving {
                    SessionCompletionView(
                        sentences: sentences,
                        displayCategories: displayCategories,
                        isExtending: isExtending,
                        onExtend: extendTapped,
                        onFinish: {
                            isLeaving = true
                            onFinish(true)
                        }
                    )
                }

                if let primaryActionButtonTitle {
                    Button(action: handlePrimaryActionButtonTap) {
                        Text(primaryActionButtonTitle)
                            .font(.jakarta(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(finishGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    #if os(macOS)
                    .padding(.bottom, 50)
                    #else
                    .padding(.bottom, 20)
                    #endif
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!showSigningSentenceCompletionOverlay)

            if showSigningSentenceCompletionOverlay {
                SentenceCompletionOverlay(
                    averageScore: signingSentenceAverageScore,
                    isFavorited: $isSigningSentenceFavorited,
                    onContinue: continueAfterSigningSentenceOverlay
                )
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .bottom)
                #if os(macOS)
                .transition(.opacity)
                #else
                .transition(.move(edge: .bottom).combined(with: .opacity))
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .macCentered(widthFraction: 0.75)
        .background {
            #if os(iOS)
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            #elseif os(macOS)
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color.white
                .ignoresSafeArea()
            #endif
        }
        .onAppear {
            #if os(macOS)
            sessionCameraVM.isMirrored = true
            #endif
            signingPageIndex = 1
            sessionCameraVM.checkPermission()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            sessionCameraVM.start()
        }
        .onDisappear {
            sessionCameraVM.stop()
        }
        .sheet(isPresented: $showLeaveConfirmation) {
            LeaveConfirmationSheet(
                onDontSave: {
                    showLeaveConfirmation = false
                    isLeaving = true
                    onFinish(false)
                },
                onSave: {
                    showLeaveConfirmation = false
                    isLeaving = true
                    onFinish(true)
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.white)
        }
    }

    private var sessionTopChrome: some View {
        Group {
            if shouldShowSessionProgressBar || !currentTopSubtitle.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if shouldShowSessionProgressBar {
                        CustomProgressBar(
                            progress: currentTopProgress,
                            trackColor: barTrack,
                            trackOpacity: 1.0,
                            fillColor: barBlue,
                            barHeight: 10
                        )
                    }

                    if !currentTopSubtitle.isEmpty {
                        Text(currentTopSubtitle)
                            .font(.jakarta(size: 20, weight: .semibold))
                            .foregroundColor(currentTopSubtitleColor)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
    }

    private func extendTapped() {
        guard !isExtending else { return }
        isExtending = true
        Task {
            await onExtend()
            await MainActor.run {
                isExtending = false
                signingPageIndex = 1
                showPracticeEntry = true
                showSigningSentenceCompletionOverlay = false
            }
        }
    }

    private func handlePrimaryActionButtonTap() {
        if showPracticeEntry {
            signingSubtitle = "New sentence!"
            signingPageIndex = 1
            showPracticeEntry = false
            return
        }

        guard currentSentenceIndex < sentences.count else { return }
        if sentences[currentSentenceIndex].practiceType != .comprehension && signingPageIndex == 1 {
            withAnimation {
                signingPageIndex = 2
            }
        }
    }

    private func continueAfterSigningSentenceOverlay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showSigningSentenceCompletionOverlay = false
        }
        markCurrentSentenceCompletedAndAdvance()
    }
}
