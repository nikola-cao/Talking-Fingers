//
//  FlashcardsServices.swift
//  Talking Fingers
//
//  Created by Na Hua on 2/12/26.
//
import Foundation
import FirebaseFirestore

final class FlashcardsServices {

    private let db = Firestore.firestore()
    private let collectionName = "flashcards"

    func uploadFlashcards(_ flashcards: [FlashcardModel]) async throws {
        let collectionRef = db.collection(collectionName)

        for card in flashcards {
            var data: [String: Any] = [
                "id": card.id.uuidString,
                "term": card.term.rawValue,
                "category": card.category.rawValue,
                "starred": card.starred,
                "progress": card.progress.rawValue
            ]
            data["lastSucceeded"] = card.lastSucceeded
            data["gifFileName"] = card.gifFileName ?? card.term.defaultGifFileName
            try await collectionRef.document(card.id.uuidString).setData(data)
        }
    }
    
    /// Skips documents that fail to decode rather than failing the whole download.
    func downloadFlashcards() async throws -> [FlashcardModel] {
        let snapshot = try await db.collection(collectionName).getDocuments()
        return snapshot.documents.compactMap { flashcard(from: $0.data()) }
    }

    private func flashcard(from data: [String: Any]) -> FlashcardModel? {
        guard let id = UUID(uuidString: data["id"] as? String ?? ""),
              let termString = data["term"] as? String,
              let term = Term(rawValue: termString),
              let categoryString = data["category"] as? String,
              let category = TermCategory(rawValue: categoryString),
              let starred = data["starred"] as? Bool,
              let progressString = data["progress"] as? String else {
            return nil
        }

        let progress = ProgressType(rawValue: progressString.lowercased()) ?? .new

        return FlashcardModel(
            term: term,
            id: id,
            lastSucceeded: (data["lastSucceeded"] as? Timestamp)?.dateValue(),
            starred: starred,
            progress: progress,
            category: category,
            gifFileName: data["gifFileName"] as? String
        )
    }
}
