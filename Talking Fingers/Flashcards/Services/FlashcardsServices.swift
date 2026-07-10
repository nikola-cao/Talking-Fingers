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
/// The app bundle is the authority on what cards exist (the `Term` enum);
/// Firestore only transports each user's mutable progress between devices —
/// one document per term at `Users/{uid}/cardProgress/{term}`.
///
/// `updatedAt` records when the user performed the action (client time), not
/// when it was uploaded, so merging is "newest action wins" even for changes
/// that were made offline and uploaded later.
final class FlashcardsServices {

    struct CardProgress {
        let term: Term
        let progress: ProgressType
        let starred: Bool
        let lastSucceeded: Date?
        let updatedAt: Date?
    }

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        stopListening()
    }

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
                "updatedAt": Timestamp(date: card.progressUpdatedAt ?? Date())
            ]
            if let lastSucceeded = card.lastSucceeded {
                data["lastSucceeded"] = Timestamp(date: lastSucceeded)
            }
            batch.setData(data, forDocument: collection.document(card.term.rawValue), merge: true)
        }
        try await batch.commit()
    }

    /// Observes the user's progress in real time. The first snapshot hydrates
    /// local state on launch; later snapshots apply changes in place.
    /// Snapshots that only echo this device's own pending writes are skipped.
    /// Replaces any previous listener.
    func startListening(onChange: @escaping ([CardProgress]) -> Void) {
        stopListening()
        guard let collection = progressCollection else { return }

        listener = collection.addSnapshotListener { snapshot, error in
            guard let snapshot else {
                print("Progress listener error: \(String(describing: error))")
                return
            }
            guard !snapshot.metadata.hasPendingWrites else { return }
            onChange(snapshot.documents.compactMap(Self.cardProgress(from:)))
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Documents that fail to decode (e.g. for terms removed from the app) are skipped;
    /// the app bundle is the authority on which terms exist.
    private static func cardProgress(from document: QueryDocumentSnapshot) -> CardProgress? {
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
