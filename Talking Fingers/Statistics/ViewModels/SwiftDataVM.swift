//
//  SwiftDataVM.swift
//  Talking Fingers
//
//  Created by Krish Prasad on 2/4/26.
//

import Observation
import SwiftData
import Foundation

@Observable
class SwiftDataVM {
    var modelContext: ModelContext?
    var savedPractices: [SavedPracticeModel] = []
    private let profileService = UserProfileService()
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func generatePromptForLLM(from flashcards: [FlashcardModel], focusTerms: [Term] = []) -> String {
        return PromptGenerator.generatePromptForLLM(from: flashcards, focusTerms: focusTerms)
    }
    
    func fetchFlashcards() -> [FlashcardModel] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            let descriptor = FetchDescriptor<FlashcardModel>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching flashcards: \(error)")
            return []
        }
    }
    
    func generatePromptFromCurrentData(focusTerms: [Term] = []) -> String {
        let flashcards = fetchFlashcards()
        if flashcards.isEmpty { 
            return "Error: No flashcards available to generate prompt." 
        }
        return generatePromptForLLM(from: flashcards, focusTerms: focusTerms)
    }
    
    
    func updateFlashcardProgress(flashcards: [FlashcardModel], scores: [Int]) {
        guard flashcards.count == scores.count else { return }
        
        for index in 0..<scores.count {
            let card = flashcards[index]
            let previousProgress = card.progress
            if scores[index] == 1 {
                card.progress = previousProgress.increase()
            } else if scores[index] == -1 {
                card.progress = previousProgress.decrease()
            }
            if card.progress != previousProgress {
                card.markProgressChanged()
            }
            if scores[index] != 0 {
                recordAttempt(term: card.term, correct: scores[index] == 1)
            }
        }
        try? modelContext?.save()
        recordDailyMasterySnapshotIfNeeded()
    }
    // MARK: - AI Sentence Comprehension Grading
    func gradeSentenceComprehension(correctGloss: [Term], userAnswers: [String]) -> [Int] {
        var score: [Int] = []
        
        for i in 0..<correctGloss.count {
            if i < userAnswers.count {
                let correctWord = correctGloss[i].rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let userWord = userAnswers[i].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                if correctWord == userWord {
                    score.append(1)
                } else {
                    score.append(-1)
                }
            } else {
                score.append(-1)
            }
        }
        
        return score
    }
    
    // MARK: - Saved Practice Sessions
    func savePracticeSession(sentences: [AISentenceModel], categories: [String], title: String = "") {
        guard let modelContext = modelContext else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPractice = SavedPracticeModel(
            sentences: sentences,
            categories: categories,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle
        )
        modelContext.insert(savedPractice)
        
        persistModelContext()
    }

    /// Persists pending changes (e.g. after mutating an existing `SavedPracticeModel`).
    func persistModelContext() {
        guard let modelContext = modelContext else { return }
        do {
            try modelContext.save()
        } catch {
            print("Error saving SwiftData context: \(error)")
        }
    }
    
    func fetchSavedPracticeSessions() -> [SavedPracticeModel] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            var descriptor = FetchDescriptor<SavedPracticeModel>()
            descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching saved practice sessions: \(error)")
            return []
        }
    }
    func getFlashcardsForGloss(_ gloss: [Term]) -> [FlashcardModel] {
        let allFlashcards = fetchFlashcards()
        let glossTermStrings = gloss.map { $0.rawValue }
        
        return glossTermStrings.compactMap { termString in
            allFlashcards.first { $0.term.rawValue == termString }
        }
    }
    
    func updateStreak(for user: User) {
        let now = Date()
        let calendar = Calendar.current
        
        guard let lastDate = user.lastActivity else {
            user.streakCount = 1
            user.lastActivity = now
            markProfileChanged(user)
            persistAndSyncProfile(user)
            return
        }
        
        if calendar.isDateInToday(lastDate) {
            user.lastActivity = now
        } else if calendar.isDateInYesterday(lastDate) {
            user.streakCount += 1
            user.lastActivity = now
        } else {
            user.streakCount = 1
            user.lastActivity = now
        }

        markProfileChanged(user)
        persistAndSyncProfile(user)
    }
        
    func checkAndResetStreak(for user: User) {
        guard let lastDate = user.lastActivity else { return }
        let calendar = Calendar.current
        
        if !calendar.isDateInToday(lastDate) && !calendar.isDateInYesterday(lastDate) {
            user.streakCount = 0
            markProfileChanged(user)
            persistAndSyncProfile(user)
        }
    }

    // MARK: - Profile Sync

    /// Ensures the signed-in user exists in SwiftData and merges remote profile data.
    func syncAuthenticatedUser(_ authUser: User) async {
        guard let modelContext else { return }

        let localUser = fetchLocalUser(userId: authUser.userId) ?? {
            let inserted = User(
                userId: authUser.userId,
                name: authUser.name,
                email: authUser.email,
                handedness: authUser.handedness
            )
            modelContext.insert(inserted)
            return inserted
        }()

        localUser.name = authUser.name
        localUser.email = authUser.email
        if let handedness = authUser.handedness {
            localUser.handedness = handedness
        }
        if localUser.lastActivity == nil || (authUser.profileUpdatedAt ?? .distantPast) >= (localUser.profileUpdatedAt ?? .distantPast) {
            localUser.streakCount = authUser.streakCount
            localUser.lastActivity = authUser.lastActivity
            localUser.profileUpdatedAt = authUser.profileUpdatedAt
        }

        await pushPendingProfileChanges(for: localUser)

        do {
            if let remote = try await profileService.downloadProfile() {
                applyRemoteProfile(remote, to: localUser)
            }
        } catch {
            print("Failed to download user profile: \(error)")
        }

        authUser.streakCount = localUser.streakCount
        authUser.lastActivity = localUser.lastActivity
        authUser.handedness = localUser.handedness
        try? modelContext.save()
    }

    func updateProfile(for user: User, name: String? = nil, handedness: String? = nil) async {
        if let name {
            user.name = name
        }
        if let handedness {
            user.handedness = handedness.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        markProfileChanged(user)
        persistAndSyncProfile(user)
    }

    func localUser(matching userId: String) -> User? {
        fetchLocalUser(userId: userId)
    }

    // MARK: - Practice Tracking

    func recordAttempt(term: Term, correct: Bool, date: Date = Date()) {
        guard let modelContext else { return }
        modelContext.insert(PracticeAttemptModel(term: term, correct: correct, date: date))
        try? modelContext.save()
    }

    func recordDailyMasterySnapshotIfNeeded() {
        guard let modelContext else { return }

        let flashcards = fetchFlashcards()
        guard !flashcards.isEmpty else { return }

        let mastery = masteryPercentage(for: flashcards)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<AnalyticsModel>(
            predicate: #Predicate<AnalyticsModel> { snapshot in
                snapshot.date >= startOfToday
            }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            if let latest = existing.max(by: { $0.date < $1.date }) {
                latest.value = mastery
                latest.date = Date()
            }
            try? modelContext.save()
            return
        }

        modelContext.insert(AnalyticsModel(date: Date(), value: mastery))
        try? modelContext.save()
    }

    // MARK: - Stats Queries

    func wordsLearnedCount() -> Int {
        fetchFlashcards().filter { $0.progress == .mastered }.count
    }

    func masteryPercentage(for flashcards: [FlashcardModel]) -> Float {
        guard !flashcards.isEmpty else { return 0 }
        var total: Float = 0
        for card in flashcards {
            switch card.progress {
            case .new: total += 0
            case .learning: total += 40
            case .polishing: total += 70
            case .mastered: total += 100
            }
        }
        return total / Float(flashcards.count)
    }

    func recentMasterySnapshots(limit: Int = 7) -> [AnalyticsModel] {
        guard let modelContext else { return [] }
        var descriptor = FetchDescriptor<AnalyticsModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func weeklyAttemptCounts() -> [Int] {
        guard let modelContext else { return Array(repeating: 0, count: 7) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return Array(repeating: 0, count: 7)
        }

        let descriptor = FetchDescriptor<PracticeAttemptModel>(
            predicate: #Predicate<PracticeAttemptModel> { attempt in
                attempt.date >= weekStart
            }
        )
        let attempts = (try? modelContext.fetch(descriptor)) ?? []

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return attempts.filter { $0.date >= day && $0.date < nextDay }.count
        }
    }

    func accuracyByCategory(limit: Int = 4) -> [(category: TermCategory, percentage: Int)] {
        guard let modelContext else { return [] }

        let descriptor = FetchDescriptor<PracticeAttemptModel>()
        let attempts = (try? modelContext.fetch(descriptor)) ?? []
        guard !attempts.isEmpty else { return [] }

        let grouped = Dictionary(grouping: attempts) { $0.categoryRawValue }
        let rows = grouped.compactMap { key, values -> (TermCategory, Int)? in
            guard let category = TermCategory(rawValue: key), !values.isEmpty else { return nil }
            let correct = values.filter(\.correct).count
            let percentage = Int((Double(correct) / Double(values.count) * 100).rounded())
            return (category, percentage)
        }
        .sorted { $0.1 > $1.1 }
        return Array(rows.prefix(limit))
    }

    func practicedDaysThisWeek() -> Set<Int> {
        guard let modelContext else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        let descriptor = FetchDescriptor<PracticeAttemptModel>(
            predicate: #Predicate<PracticeAttemptModel> { attempt in
                attempt.date >= weekStart
            }
        )
        let attempts = (try? modelContext.fetch(descriptor)) ?? []

        return Set(attempts.compactMap { attempt in
            let day = calendar.startOfDay(for: attempt.date)
            return calendar.dateComponents([.day], from: weekStart, to: day).day
        })
    }

    // MARK: - Private

    private func fetchLocalUser(userId: String) -> User? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.userId == userId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func markProfileChanged(_ user: User) {
        user.profileUpdatedAt = Date()
        user.needsProfileSync = true
    }

    private func persistAndSyncProfile(_ user: User) {
        try? modelContext?.save()
        Task { await pushPendingProfileChanges(for: user) }
    }

    private func pushPendingProfileChanges(for user: User) async {
        guard user.needsProfileSync else { return }
        do {
            try await profileService.uploadProfile(for: user)
            await MainActor.run {
                user.needsProfileSync = false
                try? modelContext?.save()
            }
        } catch {
            print("Failed to upload user profile, will retry next sync: \(error)")
        }
    }

    private func applyRemoteProfile(_ remote: UserProfileService.RemoteProfile, to local: User) {
        let remoteUpdatedAt = remote.profileUpdatedAt ?? .distantPast
        let localUpdatedAt = local.profileUpdatedAt ?? .distantPast

        if remoteUpdatedAt > localUpdatedAt {
            local.name = remote.name.isEmpty ? local.name : remote.name
            local.email = remote.email.isEmpty ? local.email : remote.email
            if let handedness = remote.handedness {
                local.handedness = handedness
            }
            local.streakCount = remote.streakCount
            local.lastActivity = remote.lastActivity
            local.profileUpdatedAt = remote.profileUpdatedAt
            local.needsProfileSync = false
        }
    }
}
