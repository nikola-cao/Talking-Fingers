import SwiftUI
import SwiftData

struct SavedPracticeView: View {
    @Environment(SwiftDataVM.self) private var dataVM
    @Query(sort: \SavedPracticeModel.date, order: .reverse) private var savedSessions: [SavedPracticeModel]

    @State private var expandedCardID: UUID?
    @State private var createPracticeSheetMode: CreatePracticeSheetMode?
    @State private var showSessionView = false
    @State private var sessionSentences: [AISentenceModel] = []
    @State private var lastCategories: Set<TermCategory>?
    @State private var lastPracticeTitle: String = ""
    @State private var lastModeSelection = PracticeModeSelection(signing: true, comprehension: false)
    @State private var savedSessionStartSentenceIndex: Int = 0
    @State private var practiceSessionIdentity = UUID()
    @State private var shouldPersistSessionOnFinish = true
    @State private var isExistingSavedPractice = false

    private func displayTitle(for session: SavedPracticeModel) -> String {
        if let t = session.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return session.categories.joined(separator: " + ").capitalized
    }

    private func trainingItem(for session: SavedPracticeModel) -> TrainingItem {
        let completedCount = session.sentences.filter(\.completed).count
        let totalCount = session.sentences.count
        let isComplete = completedCount == totalCount && totalCount > 0
        let sessionModeSelection = modeSelection(for: session)

        let completedSentences = session.sentences.filter(\.completed)
        let accuracies = completedSentences.compactMap(\.accuracy)
        let averageAccuracy: Double? = {
            guard isComplete, !accuracies.isEmpty else { return nil }
            return accuracies.reduce(0, +) / Double(accuracies.count)
        }()
        let completionProgress: Double = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0

        return TrainingItem(
            id: session.id,
            title: displayTitle(for: session),
            subtitle: session.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()),
            accuracy: averageAccuracy,
            isComplete: isComplete,
            completionProgress: completionProgress,
            iconName: sessionModeSelection.comprehension && !sessionModeSelection.signing ? "eye" : "hand.wave"
        )
    }

    var body: some View {
        mainContent
            .sheet(item: $createPracticeSheetMode) { sheetMode in
            let initialModeSelection = sheetMode.modeSelection
            GenerateSentencesView(initialModeSelection: initialModeSelection) { sentences, categories, practiceTitle in
                lastModeSelection = initialModeSelection
                lastCategories = categories
                lastPracticeTitle = practiceTitle
                sessionSentences = sentences
                savedSessionStartSentenceIndex = 0
                practiceSessionIdentity = UUID()
                shouldPersistSessionOnFinish = true
                isExistingSavedPractice = false
                createPracticeSheetMode = nil
                // Wait for the sheet dismissal animation to fully complete before
                // presenting the full screen cover. This prevents SwiftUI from
                // capturing stale state values during the presentation transition.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showSessionView = true
                }
            }
            .presentationDetents([.height(460), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.white)
        }
        .universalFullScreenCover(isPresented: $showSessionView) {
            PracticeSessionView(
                sentences: $sessionSentences,
                practiceTitle: lastPracticeTitle.isEmpty ? "Practice" : lastPracticeTitle,
                selectedCategories: lastCategories,
                initialSentenceIndex: savedSessionStartSentenceIndex,
                isExistingSavedPractice: isExistingSavedPractice,
                onFinish: { shouldSave in
                    if shouldSave && shouldPersistSessionOnFinish {
                        saveSessionToDatabase()
                    }
                    showSessionView = false
                },
                onExtend: {
                    guard let categories = lastCategories else { return }
                    do {
                        let more = try await GenerateSentencesView.generateSentences(
                            categories: categories,
                            modeSelection: lastModeSelection
                        )
                        await MainActor.run {
                            sessionSentences.append(contentsOf: more)
                            shouldPersistSessionOnFinish = true
                        }
                    } catch {
                        // Keep current session state if extend fails.
                    }
                }
            )
            .id(practiceSessionIdentity)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        // On macOS, only the "My trainings" list scrolls — the header,
        // "Start a new practice" cards, and section title stay pinned.
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            VStack(alignment: .leading, spacing: 20) {
                startNewPracticeSection
                trainingSectionTitle
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                trainingCardsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
        .macCentered(widthFraction: 0.75)
        // Edge-to-edge gradient behind the header on macOS, rendered
        // *outside* the centered content so it spans the full window width
        // and extends into the top safe area.
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: "#EEF6FB"), Color(hex: "#DEECF8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 125)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)
        }
        .background(Color.white.ignoresSafeArea())
        #else
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    startNewPracticeSection
                    trainingSectionTitle
                    trainingCardsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        #endif
    }

    private var headerSection: some View {
        Text("Practice")
            .font(.jakarta(size: 32, weight: .bold))
            .foregroundColor(Color(hex: "#2A7BBC"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            #if os(macOS)
            .padding(.top, 80)
            #else
            .padding(.top, 8)
            .padding(.bottom, 14)
            #endif
            #if os(iOS)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#EEF6FB"), Color(hex: "#DEECF8")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 125)
                .ignoresSafeArea(edges: .top),
                alignment: .top
            )
            #endif
    }

    private var startNewPracticeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start a new practice")
                .font(.jakarta(size: 20, weight: .semibold))
                .foregroundColor(.black.opacity(0.78))

            #if os(macOS)
            // Side-by-side on the wider macOS layout
            HStack(spacing: 20) {
                PracticeModeCard(
                    title: "Sign",
                    subtitle: "Sign sentences to someone else",
                    tint: Color(hex: "#71A046"),
                    backgroundTop: Color(hex: "#F4F9F1"),
                    backgroundBottom: Color(hex: "#EAF3E3"),
                    border: Color(hex: "#ADCE8F"),
                    imageAssetName: "SentencesSignFlowerPartial",
                    placeholderOnLeading: true
                ) {
                    createPracticeSheetMode = .signing
                }

                PracticeModeCard(
                    title: "Comprehend",
                    subtitle: "Understand sentences signed to you",
                    tint: Color(hex: "#5E9ECC"),
                    backgroundTop: Color(hex: "#EEF6FB"),
                    backgroundBottom: Color(hex: "#E6F1F9"),
                    border: Color(hex: "#A5C1D8"),
                    imageAssetName: "SentencesComprehendFlowerPartial",
                    placeholderOnLeading: false
                ) {
                    createPracticeSheetMode = .comprehension
                }
            }
            #else
            PracticeModeCard(
                title: "Sign",
                subtitle: "Sign sentences to\nsomeone else",
                tint: Color(hex: "#71A046"),
                backgroundTop: Color(hex: "#F4F9F1"),
                backgroundBottom: Color(hex: "#EAF3E3"),
                border: Color(hex: "#ADCE8F"),
                imageAssetName: "SentencesSignFlowerPartial",
                placeholderOnLeading: true
            ) {
                createPracticeSheetMode = .signing
            }

            PracticeModeCard(
                title: "Comprehend",
                subtitle: "Understand sentences\nsigned to you",
                tint: Color(hex: "#5E9ECC"),
                backgroundTop: Color(hex: "#EEF6FB"),
                backgroundBottom: Color(hex: "#E6F1F9"),
                border: Color(hex: "#A5C1D8"),
                imageAssetName: "SentencesComprehendFlowerPartial",
                placeholderOnLeading: false
            ) {
                createPracticeSheetMode = .comprehension
            }
            #endif
        }
    }

    private enum CreatePracticeSheetMode: String, Identifiable {
        case signing
        case comprehension

        var id: String { rawValue }

        var modeSelection: PracticeModeSelection {
            switch self {
            case .signing:
                return PracticeModeSelection(signing: true, comprehension: false)
            case .comprehension:
                return PracticeModeSelection(signing: false, comprehension: true)
            }
        }
    }

    private var trainingSectionTitle: some View {
        Text("My Practices")
            .font(.jakarta(size: 20, weight: .semibold))
            .foregroundColor(.black.opacity(0.78))
            .padding(.top, 6)
    }

    private var trainingCardsSection: some View {
        VStack(spacing: 14) {
            ForEach(savedSessions, id: \.id) { session in
                let item = trainingItem(for: session)
                TrainingCard(
                    item: item,
                    isExpanded: expandedCardID == item.id,
                    onTapCard: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            if expandedCardID == item.id {
                                expandedCardID = nil
                            } else {
                                expandedCardID = item.id
                            }
                        }
                    },
                    onReview: {
                        openSavedSession(session, kind: .review)
                    },
                    onRetry: {
                        openSavedSession(session, kind: .retry)
                    },
                    actionType: session.sentences.allSatisfy(\.completed) ? .retry : .continueSession
                )
            }
        }
    }

    private enum SavedSessionOpenKind {
        case review
        case retry
    }

    private func openSavedSession(_ session: SavedPracticeModel, kind: SavedSessionOpenKind) {
        switch kind {
        case .review:
            sessionSentences = session.sentences
            let firstIncomplete = session.sentences.firstIndex { !$0.completed }
            savedSessionStartSentenceIndex = firstIncomplete ?? session.sentences.count
            shouldPersistSessionOnFinish = true
        case .retry:
            sessionSentences = session.sentences.map { sentence in
                var copy = sentence
                copy.completed = false
                copy.score = nil
                copy.wordScores = nil
                copy.comprehensionAttempts = nil
                return copy
            }
            savedSessionStartSentenceIndex = 0
            shouldPersistSessionOnFinish = false
        }

        let mapped = Set(session.categories.compactMap { TermCategory(rawValue: $0) })
        lastCategories = mapped.isEmpty ? nil : mapped
        lastPracticeTitle = session.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        lastModeSelection = modeSelection(for: session)
        practiceSessionIdentity = UUID()
        isExistingSavedPractice = true
        showSessionView = true
    }

    private func modeSelection(for session: SavedPracticeModel) -> PracticeModeSelection {
        let hasComprehension = session.sentences.contains { $0.practiceType == .comprehension }
        let hasSigning = session.sentences.contains { $0.practiceType != .comprehension }
        return PracticeModeSelection(signing: hasSigning, comprehension: hasComprehension)
    }

    private func saveSessionToDatabase() {
        guard !sessionSentences.isEmpty else {
            sessionSentences = []
            return
        }
        let categoryStrings = lastCategories?.map { $0.rawValue } ?? ["General"]

        if let existingSession = savedSessions.first(where: { session in
            guard let a = session.sentences.first?.id, let b = sessionSentences.first?.id else { return false }
            return a == b
        }) {
            existingSession.sentences = sessionSentences
            existingSession.date = Date()
            let trimmed = lastPracticeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            existingSession.title = trimmed.isEmpty ? nil : trimmed
            dataVM.persistModelContext()
        } else {
            dataVM.savePracticeSession(
                sentences: sessionSentences,
                categories: categoryStrings,
                title: lastPracticeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        sessionSentences = []
        lastPracticeTitle = ""
    }
}

#Preview {
    let schema = Schema([SavedPracticeModel.self, FlashcardModel.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let vm = SwiftDataVM(modelContext: container.mainContext)

    SavedPracticeView()
        .modelContainer(container)
        .environment(vm)
}
