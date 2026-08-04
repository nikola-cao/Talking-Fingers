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
    private let practiceService = SavedPracticeService()

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
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

        practiceDidChange(savedPractice)
    }

    /// Persists a locally changed practice and uploads it. If the upload fails
    /// (e.g. offline) the practice stays flagged and is retried by the next
    /// `syncSavedPractices()`.
    func practiceDidChange(_ practice: SavedPracticeModel) {
        practice.updatedAt = Date()
        practice.needsSync = true
        persistModelContext()

        Task {
            do {
                try await practiceService.upload([practice])
                await MainActor.run {
                    practice.needsSync = false
                    persistModelContext()
                }
            } catch {
                print("Failed to upload practice, will retry next sync: \(error)")
            }
        }
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

        // Registration couldn't write the profile document (rules, App Check,
        // a cold ID token). Carry the flag over so the retry below actually
        // fires instead of the account never getting a profile doc at all.
        if authUser.needsProfileSync {
            localUser.profileUpdatedAt = authUser.profileUpdatedAt ?? Date()
            localUser.needsProfileSync = true
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

    func localUser(matching userId: String) -> User? {
        fetchLocalUser(userId: userId)
    }

    // MARK: - Account Scoping

    /// Wipes the local store when a *different* account signs in.
    ///
    /// Everything in SwiftData is device-scoped — only `User` carries a uid,
    /// and nothing queries by it — so without this the previous account's card
    /// progress, practices and stats silently become the new account's.
    /// Signing back into the same account keeps its data, so a plain sign-out
    /// costs the user nothing.
    ///
    /// Runs synchronously: it must complete before any view reads the store.
    func prepareLocalStore(for userId: String) {
        defer { LocalAccountStore.lastSignedInUserId = userId }

        if let recordedUserId = LocalAccountStore.lastSignedInUserId {
            guard recordedUserId != userId else { return }
        } else {
            // Upgrade path: devices that signed in before this key existed.
            // Fall back to the `User` rows already in the store — one from
            // another account means the local data isn't this account's.
            guard localUserIds().contains(where: { $0 != userId }) else { return }
        }

        wipeLocalUserData()
    }

    /// Deletes every user-scoped row. The flashcard deck is re-seeded from
    /// `Term.allCases` on the next load and re-hydrated from the new account's
    /// Firestore progress, so dropping the rows loses nothing recoverable.
    private func wipeLocalUserData() {
        guard let modelContext else { return }
        do {
            try modelContext.delete(model: FlashcardModel.self)
            try modelContext.delete(model: SavedPracticeModel.self)
            try modelContext.delete(model: PracticeAttemptModel.self)
            try modelContext.delete(model: AnalyticsModel.self)
            try modelContext.delete(model: User.self)
            try modelContext.save()
            savedPractices = []
        } catch {
            print("Failed to reset local store on account switch: \(error)")
        }
    }

    private func localUserIds() -> [String] {
        guard let modelContext else { return [] }
        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        return users.map(\.userId)
    }

    // MARK: - Saved Practice Sync

    /// Pushes practices changed locally, then merges what the account has
    /// stored remotely. Called on sign-in, after `prepareLocalStore`.
    func syncSavedPractices() async {
        await pushPendingPractices()
        await pullRemotePractices()
    }

    private func pushPendingPractices() async {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SavedPracticeModel>(
            predicate: #Predicate<SavedPracticeModel> { $0.needsSync }
        )
        guard let dirtyPractices = try? modelContext.fetch(descriptor), !dirtyPractices.isEmpty else { return }

        do {
            try await practiceService.upload(dirtyPractices)
            await MainActor.run {
                for practice in dirtyPractices { practice.needsSync = false }
                persistModelContext()
            }
        } catch {
            print("Failed to push \(dirtyPractices.count) pending practice(s), will retry next sync: \(error)")
        }
    }

    private func pullRemotePractices() async {
        do {
            let remotePractices = try await practiceService.downloadPractices()
            guard !remotePractices.isEmpty else { return }
            await MainActor.run { applyRemotePractices(remotePractices) }
        } catch {
            print("Failed to download practices: \(error)")
        }
    }

    /// Newest action wins, matching card progress: a remote practice is only
    /// applied when it's strictly newer than the local copy.
    private func applyRemotePractices(_ remotePractices: [SavedPracticeService.RemotePractice]) {
        guard let modelContext else { return }

        let existing = (try? modelContext.fetch(FetchDescriptor<SavedPracticeModel>())) ?? []
        let localByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for remote in remotePractices {
            guard let local = localByID[remote.id] else {
                modelContext.insert(
                    SavedPracticeModel(
                        id: remote.id,
                        date: remote.date,
                        sentencesData: remote.sentencesData,
                        categories: remote.categories,
                        title: remote.title,
                        updatedAt: remote.updatedAt
                    )
                )
                continue
            }

            guard remote.updatedAt > (local.updatedAt ?? .distantPast) else { continue }
            local.date = remote.date
            local.sentencesData = remote.sentencesData
            local.categories = remote.categories
            local.title = remote.title
            local.updatedAt = remote.updatedAt
            local.needsSync = false
        }

        persistModelContext()
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
