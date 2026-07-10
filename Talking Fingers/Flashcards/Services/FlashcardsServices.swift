//
//  FlashcardsServices.swift
//  Talking Fingers
//
//  Created by Na Hua on 2/12/26.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Syncs per-user flashcard progress with Firestore.
///
/// Card content (term, category, gif) is defined by the `Term` enum bundled in
/// the app, so only the user's mutable state is stored remotely — one document
/// per term at `Users/{uid}/cardProgress/{term}`. Terms are stable across
/// devices, unlike the locally generated card UUIDs.
final class FlashcardsServices {

    struct CardProgress {
        let term: Term
        let progress: ProgressType
        let starred: Bool
        let lastSucceeded: Date?
        let updatedAt: Date?
    }

    private let db = Firestore.firestore()

    /// `nil` when no user is signed in, in which case sync is skipped
    /// and the app operates on local data only.
    private var progressCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("Users").document(uid).collection("cardProgress")
    }

    /// Uploads the user's progress for the given cards in a single batched write.
    func uploadProgress(for cards: [FlashcardModel]) async throws {
        guard let collection = progressCollection, !cards.isEmpty else { return }

        let batch = db.batch()
        for card in cards {
            var data: [String: Any] = [
                "progress": card.progress.rawValue,
                "starred": card.starred,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let lastSucceeded = card.lastSucceeded {
                data["lastSucceeded"] = Timestamp(date: lastSucceeded)
            }
            batch.setData(data, forDocument: collection.document(card.term.rawValue), merge: true)
        }
        try await batch.commit()
    }

    /// Downloads all progress documents for the signed-in user.
    /// Documents that fail to decode (e.g. for terms removed from the app) are skipped.
    func downloadProgress() async throws -> [CardProgress] {
        guard let collection = progressCollection else { return [] }

        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { document in
            guard let term = Term(rawValue: document.documentID) else { return nil }
            let data = document.data()
            guard let progressString = data["progress"] as? String,
                  let progress = ProgressType(rawValue: progressString) else { return nil }

            return CardProgress(
                term: term,
                progress: progress,
                starred: data["starred"] as? Bool ?? false,
                lastSucceeded: (data["lastSucceeded"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
            )
        }
    }
}
