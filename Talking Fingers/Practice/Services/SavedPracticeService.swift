//
//  SavedPracticeService.swift
//  Talking Fingers
//
//  Syncs saved practices with Firestore, one document per practice at
//  `Users/{uid}/practices/{id}`.
//
//  The sentence list travels as the same JSON blob SwiftData stores locally,
//  so the wire format never drifts from `AISentenceModel`'s `Codable`
//  representation. `updatedAt` is client time, matching the newest-action-wins
//  merge used for card progress.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class SavedPracticeService {

    struct RemotePractice {
        let id: UUID
        let date: Date
        let categories: [String]
        let title: String?
        let sentencesData: Data
        let updatedAt: Date
    }

    /// `nil` when no user is signed in, in which case sync is skipped and the
    /// app operates on local data only.
    private var practiceCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firebase.users.document(uid).collection("practices")
    }

    func upload(_ practices: [SavedPracticeModel]) async throws {
        guard let collection = practiceCollection, !practices.isEmpty else { return }

        let batch = Firebase.db.batch()
        for practice in practices {
            var data: [String: Any] = [
                "date": Timestamp(date: practice.date),
                "categories": practice.categories,
                "sentences": String(data: practice.sentencesData, encoding: .utf8) ?? "",
                "updatedAt": Timestamp(date: practice.updatedAt ?? Date())
            ]
            if let title = practice.title {
                data["title"] = title
            }
            batch.setData(data, forDocument: collection.document(practice.id.uuidString), merge: true)
        }
        try await batch.commit()
    }

    func downloadPractices() async throws -> [RemotePractice] {
        guard let collection = practiceCollection else { return [] }
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap(Self.practice(from:))
    }

    /// Documents that can't be decoded are skipped rather than failing the
    /// whole pull — one bad practice shouldn't cost the user the rest.
    private static func practice(from document: QueryDocumentSnapshot) -> RemotePractice? {
        guard let id = UUID(uuidString: document.documentID) else { return nil }
        let data = document.data()
        guard let sentences = data["sentences"] as? String,
              let sentencesData = sentences.data(using: .utf8) else { return nil }

        return RemotePractice(
            id: id,
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            categories: data["categories"] as? [String] ?? [],
            title: data["title"] as? String,
            sentencesData: sentencesData,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        )
    }
}
