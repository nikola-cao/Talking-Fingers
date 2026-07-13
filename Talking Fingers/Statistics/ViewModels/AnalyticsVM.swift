//
//  AnalyticsVM.swift
//  Talking Fingers
//
//  Created by Krish Prasad on 2/16/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
class AnalyticsVM {
    private var modelContext: ModelContext?

    var widgets: [StatsWidget] = []

    var isEditing = false
    var isShowingAddSheet = false
    var showDeleteAlert = false
    var pendingDelete: StatsWidget? = nil

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        fetchWidgets()
    }

    func fetchWidgets() {
        guard let modelContext else {
            widgets = []
            return
        }
        do {
            let descriptor = FetchDescriptor<StatsWidget>(
                sortBy: [SortDescriptor(\.displayOrder)]
            )
            widgets = try modelContext.fetch(descriptor)

            if widgets.isEmpty {
                seedDefaults()
            }
        } catch {
            print("Error fetching widgets: \(error)")
            widgets = []
        }
    }

    func startEditing() {
        isEditing = true
    }

    func doneEditing() {
        isEditing = false
    }

    func addWidget(title: String) {
        guard let modelContext else { return }
        let nextOrder = (widgets.last?.displayOrder ?? -1) + 1
        let widget = StatsWidget(title: title, displayOrder: nextOrder)
        modelContext.insert(widget)
        save()
        fetchWidgets()
    }

    func removeWidget(_ widget: StatsWidget) {
        guard let modelContext else { return }
        modelContext.delete(widget)
        save()
        fetchWidgets()
        reindexDisplayOrder()
    }

    func moveWidget(from source: Int, to destination: Int) {
        widgets.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
        reindexDisplayOrder()
    }

    func requestDelete(_ widget: StatsWidget) {
        pendingDelete = widget
        showDeleteAlert = true
    }

    func confirmDelete() {
        if let widget = pendingDelete {
            removeWidget(widget)
        }
        pendingDelete = nil
    }

    func cancelDelete() {
        pendingDelete = nil
    }
    
    func totalMasteryOverTime(flashcards: [FlashcardModel]) -> AnalyticsModel {
        let value = masteryPercentage(for: flashcards)
        let snapshot = AnalyticsModel(date: Date(), value: value)
        modelContext?.insert(snapshot)
        save()
        return snapshot
    }

    func masteryPercentage(for flashcards: [FlashcardModel]) -> Float {
        guard !flashcards.isEmpty else { return 0 }
        var total: Float = 0
        for flashcard in flashcards {
            switch flashcard.progress {
            case .new: total += 0
            case .learning: total += 40
            case .polishing: total += 70
            case .mastered: total += 100
            }
        }
        return total / Float(flashcards.count)
    }

    func masteryHistory(limit: Int = 30) -> [AnalyticsModel] {
        guard let modelContext else { return [] }
        var descriptor = FetchDescriptor<AnalyticsModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func flashcardsSucceededThisWeek(flashcards: [FlashcardModel]) -> Int {
            let now = Date()
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

            return flashcards.filter { flashcard in
                guard let lastSucceeded = flashcard.lastSucceeded else { return false }
                return lastSucceeded >= oneWeekAgo && lastSucceeded <= now
            }.count
        }


    // MARK: - Private

    private func seedDefaults() {
        guard let modelContext else { return }
        let defaults = ["Widget A", "Widget B", "Widget C"]
        for (i, title) in defaults.enumerated() {
            modelContext.insert(StatsWidget(title: title, displayOrder: i))
        }
        save()
        do {
            let descriptor = FetchDescriptor<StatsWidget>(
                sortBy: [SortDescriptor(\.displayOrder)]
            )
            widgets = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching seeded widgets: \(error)")
        }
    }

    private func reindexDisplayOrder() {
        for (i, widget) in widgets.enumerated() {
            widget.displayOrder = i
        }
        save()
    }

    private func save() {
        do {
            try modelContext?.save()
        } catch {
            print("Error saving model context: \(error)")
        }
    }
}
