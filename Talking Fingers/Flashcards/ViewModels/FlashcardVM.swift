//
//  FlashcardVM.swift
//  Talking Fingers
//
//  Created by Isha Jain on 2/9/26.
//
import Foundation
import Observation
import SwiftData

@Observable
class FlashcardVM {
    var flashcards: [FlashcardModel] = []
    var isLoading = false
    private let firebaseService = FlashcardsServices()
    var lastCardID: UUID?
    /// Set before attaching the listener so the first snapshot refreshes `flashcards`
    /// after merging remote progress (replaces the one-time launch download).
    private var refreshFlashcardsOnNextSnapshot = false

    func returnProgress(flashcards: [FlashcardModel]) -> Float {
        guard !flashcards.isEmpty else { return 0.0 }
        var progressTotal: Float = 0.0

        for flashcard in flashcards {
            switch flashcard.progress {
            case .new:
                progressTotal += 0
            case .learning:
                progressTotal += 40
            case .polishing:
                progressTotal += 70
            case .mastered:
                progressTotal += 100
            }
        }
        return progressTotal / Float(flashcards.count)
    }

    
    func loadFlashcards(modelContext: ModelContext) async {
        isLoading = true
        seedMissingCards(modelContext)
        flashcards = fetchFromSwiftData(modelContext)
        isLoading = false

        // Push local changes first so offline progress can't be rolled back
        // when the listener delivers remote state.
        await pushPendingChanges(modelContext)

        refreshFlashcardsOnNextSnapshot = true
        startListening(modelContext: modelContext)
    }

    /// Uploads any cards whose local changes haven't been confirmed by Firestore yet
    /// (failed uploads, changes made offline, or changes made while signed out).
    private func pushPendingChanges(_ modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<FlashcardModel>(
            predicate: #Predicate<FlashcardModel> { $0.needsSync }
        )
        guard let dirtyCards = try? modelContext.fetch(descriptor), !dirtyCards.isEmpty else { return }

        do {
            try await firebaseService.uploadProgress(for: dirtyCards)
            await MainActor.run {
                for card in dirtyCards { card.needsSync = false }
                try? modelContext.save()
            }
        } catch {
            print("Failed to push \(dirtyCards.count) pending change(s), will retry next sync: \(error)")
        }
    }

    /// Mirrors remote changes (e.g. from another device) into local storage as
    /// they happen. Progress is applied in place on the existing model objects,
    /// so active session queues built from `flashcards` are not disturbed.
    private func startListening(modelContext: ModelContext) {
        firebaseService.startListening { [weak self] remoteProgress in
            guard let self else { return }
            self.applyRemoteProgress(remoteProgress, modelContext: modelContext)
            if self.refreshFlashcardsOnNextSnapshot {
                self.refreshFlashcardsOnNextSnapshot = false
                self.flashcards = self.fetchFromSwiftData(modelContext)
            }
        }
    }

    private func fetchFromSwiftData(_ modelContext: ModelContext) -> [FlashcardModel] {
        let descriptor = FetchDescriptor<FlashcardModel>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Ensures the local deck contains one card per `Term`. The deck content is
    /// defined by the app itself; Firestore only stores per-user progress.
    private func seedMissingCards(_ modelContext: ModelContext) {
        let existingTerms = Set(fetchFromSwiftData(modelContext).map(\.term))
        let missingTerms = Term.allCases.filter { !existingTerms.contains($0) }
        guard !missingTerms.isEmpty else { return }

        for term in missingTerms {
            modelContext.insert(FlashcardModel(term: term, id: UUID(), category: term.category))
        }
        try? modelContext.save()
    }

    /// Applies remote per-user progress onto the locally seeded deck, matching by term.
    /// Newest action wins: a remote value is only applied when its `updatedAt` is
    /// strictly newer than the local change, so offline progress is never rolled back.
    private func applyRemoteProgress(_ remoteProgress: [FlashcardsServices.CardProgress], modelContext: ModelContext) {
        guard !remoteProgress.isEmpty else { return }

        let cardsByTerm = Dictionary(grouping: fetchFromSwiftData(modelContext), by: \.term)
        for progress in remoteProgress {
            for card in cardsByTerm[progress.term] ?? [] {
                if let localUpdatedAt = card.progressUpdatedAt,
                   (progress.updatedAt ?? .distantPast) <= localUpdatedAt {
                    continue
                }
                card.progress = progress.progress
                card.starred = progress.starred
                card.lastSucceeded = progress.lastSucceeded
                card.progressUpdatedAt = progress.updatedAt
                card.needsSync = false
            }
        }
        try? modelContext.save()
    }

    /// Persists a locally changed card and uploads its progress. If the upload
    /// fails (e.g. offline), the card stays flagged and is retried on the next sync.
    func updateFlashcard(_ card: FlashcardModel, modelContext: ModelContext) async {
        card.markProgressChanged()
        try? modelContext.save()
        
        Task {
            do {
                try await firebaseService.uploadProgress(for: [card])
                await MainActor.run {
                    card.needsSync = false
                    try? modelContext.save()
                }
            } catch {
                print("Failed to upload progress for \(card.term.rawValue), will retry next sync: \(error)")
            }
        }
    }
    
    func handleAnswer(for card: FlashcardModel, correct: Bool, user: User?, dataVM: SwiftDataVM) {
        dataVM.recordAttempt(term: card.term, correct: correct)

        if let user {
            dataVM.updateStreak(for: user)
        }
        
        let newProgress: ProgressType

        switch (card.progress, correct) {
        case (.new, true):
            newProgress = .learning
        case (.learning, true):
            newProgress = .polishing
        case (.polishing, true):
            newProgress = .mastered
        case (.mastered, true):
            newProgress = .mastered
        case (.mastered, false):
            newProgress = .polishing
        case (.polishing, false):
            newProgress = .learning
        case (.learning, false):
            newProgress = .learning
        case (.new, false):
            // Any learn/exercise exposure should move new cards forward so a full
            // learn round unlocks exercise even if the user skips or gets all wrong.
            newProgress = .learning
        }

        card.progress = newProgress
        if correct {
            card.lastSucceeded = Date()
        }
        
        if let modelContext = dataVM.modelContext {
            Task {
                await updateFlashcard(card, modelContext: modelContext)
            }
        }

        dataVM.recordDailyMasterySnapshotIfNeeded()
    }
    
    func nextCard() -> FlashcardModel? {
        guard !flashcards.isEmpty else { return nil }
        
        let now = Date()
        
        func baseWeight(for card: FlashcardModel) -> Double {
            switch card.progress {
            case .new: return 5
            case .learning: return 4
            case .polishing: return 2
            case .mastered: return 1
            }
        }
        
        // ideal amount of time before seeing cards
        func interval(for card: FlashcardModel) -> TimeInterval {
            switch card.progress {
            case .new: return 0
            case .learning: return 60 * 60 * 24 // 1 day
            case .polishing: return 60 * 60 * 24 * 3 // 3 days
            case .mastered: return 60 * 60 * 24 * 7 // 7 days
            }
        }
        
        // decides how overdue a card is to increase or lower the chance of it appearing
        func timeMultiplier(for card: FlashcardModel) -> Double {
            guard let last = card.lastSucceeded else { return 2.0 }
            let elapsed = now.timeIntervalSince(last)
            let target = interval(for: card)
            guard target > 0 else { return 1.5 }
            let ratio = elapsed / target
            if ratio >= 1 { return 2.0 }
            if ratio >= 0.5 { return 1.2 }
            return 0.6
        }
        
        let weightedPairs = flashcards.map { card -> (card: FlashcardModel, weight: Double) in
            let weight = max(0.1, baseWeight(for: card) * timeMultiplier(for: card))
            return (card, weight)
        }
        
        // filter out the last card to prevent repeats
        let filteredPairs = weightedPairs.filter { $0.card.id != lastCardID }
        let finalPairs = filteredPairs.isEmpty ? weightedPairs : filteredPairs
        
        let totalWeight = finalPairs.reduce(0) { $0 + $1.weight }
        var randomThreshold = Double.random(in: 0..<totalWeight)
        for pair in finalPairs {
            randomThreshold -= pair.weight
            if randomThreshold <= 0 {
                lastCardID = pair.card.id
                return pair.card
            }
        }
        return finalPairs.last?.card
    }
    
    func generateDailyReviewQueue(limit: Int = 5) -> DailyReviewQueue {
        let sorted = flashcards.sorted { a, b in
            if a.progress != b.progress {
                return progressRank(a) < progressRank(b)
            }
            return (a.lastSucceeded ?? .distantPast) < (b.lastSucceeded ?? .distantPast)
        }

        let topCards = Array(sorted.prefix(limit))
        return DailyReviewQueue(cards: topCards, requestedLimit: limit)
    }

    private func progressRank(_ card: FlashcardModel) -> Int {
        switch card.progress {
        case .new:       return 0
        case .learning:  return 1
        case .polishing: return 2
        case .mastered:  return 3
        }
    }
}
