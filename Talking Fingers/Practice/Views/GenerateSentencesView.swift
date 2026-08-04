//
//  GenerateSentencesView.swift
//  Talking Fingers
//
//  Created by Judy Hsu on 3/12/26.
//

import SwiftUI
import SwiftData

struct GenerateSentencesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SwiftDataVM.self) private var dataVM
    @State private var selectedCategories: Set<TermCategory> = []
    @State private var modeSelection: PracticeModeSelection
    @State private var trainingName: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isTrainingNameFocused: Bool
    
    /// Called with generated sentences and the categories used (so Extend can generate more).
    /// Parent should dismiss the sheet and start the session.
    var onSentencesGenerated: ([AISentenceModel], Set<TermCategory>, String) -> Void

    init(
        initialModeSelection: PracticeModeSelection = PracticeModeSelection(signing: true, comprehension: false),
        onSentencesGenerated: @escaping ([AISentenceModel], Set<TermCategory>, String) -> Void
    ) {
        _modeSelection = State(initialValue: initialModeSelection)
        self.onSentencesGenerated = onSentencesGenerated
    }

    private var canGenerate: Bool {
        !trainingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private var availableCategories: [TermCategory] {
        SentenceGenerationService.allowedCategories
    }

    private var effectiveCategories: Set<TermCategory> {
        selectedCategories.isEmpty ? Set(availableCategories) : selectedCategories
    }

    private var isComprehensionOnlyMode: Bool {
        modeSelection.comprehension && !modeSelection.signing
    }

    private var practiceTitle: String {
        isComprehensionOnlyMode ? "New Comprehension Practice" : "New Signing Practice"
    }

    private var practiceTitleColor: Color {
        isComprehensionOnlyMode ? TFColors.blue : TFColors.deepGreen
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(practiceTitle)
                .font(.jakarta(size: 20, weight: .semibold))
                .foregroundColor(practiceTitleColor)
                .padding(.top, 20)
            
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Categories")
                    .font(.jakarta(size: 15, weight: .semibold))
                
                FlowLayout(verticalSpacing: 8, horizontalSpacing: 8) {
                    ForEach(availableCategories, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategories.contains(category),
                            action: {
                                toggleCategory(category)
                            }
                        )
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Practice Name")
                    .font(.jakarta(size: 15, weight: .semibold))
                
                TextField("Enter practice name", text: $trainingName)
                    .font(.jakarta(size: 17))
                    .textFieldStyle(.plain)
                    .focused($isTrainingNameFocused)
                    .submitLabel(.done)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TFColors.borderLight, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.jakartaCaption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            
            Button(action: {
                startTraining()
            }) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("Start")
                        .font(.jakarta(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(TFColors.green.opacity(canGenerate ? 1.0 : 0.5))
            .cornerRadius(20)
            .disabled(!canGenerate)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 15)
        .padding(.top, 10)
        .onAppear {
            DispatchQueue.main.async {
                isTrainingNameFocused = true
            }
        }
    }
    
    private func toggleCategory(_ category: TermCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
        }
    }
    
    private func startTraining() {
        Task {
            isGenerating = true
            errorMessage = nil

            do {
                let flashcards = dataVM.fetchFlashcards()
                // Pass the learner's raw selection (which may be empty) rather
                // than `effectiveCategories` — an empty set has a specific
                // meaning to VocabularyScope (fall back to studied categories,
                // or greetings for a day-one learner) that's lost once it's
                // pre-resolved to "all categories" here.
                let sentences = try await SentenceGenerationService.generateSentences(
                    categories: selectedCategories,
                    flashcards: flashcards,
                    modeSelection: modeSelection
                )

                await MainActor.run {
                    onSentencesGenerated(sentences, effectiveCategories, trainingName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate sentences: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Category Button Component

struct CategoryButton: View {
    let category: TermCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue.capitalized)
                .font(.jakarta(size: 17, weight: .medium))
                .foregroundColor(isSelected ? TFColors.amber : TFColors.darkerGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? TFColors.paleGold : .white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isSelected ? TFColors.amber : TFColors.borderLight, lineWidth: isSelected ? 0.5 : 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct TestGenerateSentencesView: View {
    @State private var showSheet = false
    @State private var generatedSentences: [AISentenceModel] = []
    
    var body: some View {
        VStack {
            Button("Open New Training") {
                showSheet = true
            }
            .buttonStyle(.borderedProminent)
            
            if !generatedSentences.isEmpty {
                Text("Generated \(generatedSentences.count) sentences!")
                    .padding()
            }
        }
        .sheet(isPresented: $showSheet) {
            GenerateSentencesView { sentences, _, _ in
                generatedSentences = sentences
                showSheet = false
            }
        }
    }
}

#Preview {
    let schema = Schema([SavedPracticeModel.self, FlashcardModel.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let vm = SwiftDataVM(modelContext: container.mainContext)

    TestGenerateSentencesView()
        .modelContainer(container)
        .environment(vm)
}
