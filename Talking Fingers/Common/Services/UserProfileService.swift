//
//  UserProfileService.swift
//  Talking Fingers
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Syncs mutable user profile fields with Firestore at `Users/{uid}`.
final class UserProfileService {

    struct RemoteProfile {
        let name: String
        let email: String
        let handedness: String?
        let streakCount: Int
        let lastActivity: Date?
        let profileUpdatedAt: Date?
    }

    private var db: Firestore { Firebase.db }

    private var userDocument: DocumentReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firebase.users.document(uid)
    }

    func uploadProfile(for user: User) async throws {
        guard let document = userDocument else { return }

        var data: [String: Any] = [
            UserFields.userId: user.userId,
            UserFields.name: user.name,
            UserFields.email: user.email,
            UserFields.streakCount: user.streakCount,
            UserFields.profileUpdatedAt: Timestamp(date: user.profileUpdatedAt ?? Date())
        ]
        if let handedness = user.handedness {
            data[UserFields.handedness] = handedness
        }
        if let lastActivity = user.lastActivity {
            data[UserFields.lastActivity] = Timestamp(date: lastActivity)
        }
        try await document.setData(data, merge: true)
    }

    func uploadHandedness(_ handedness: String?) async throws {
        guard let document = userDocument else { return }
        var data: [String: Any] = [
            UserFields.profileUpdatedAt: Timestamp(date: Date())
        ]
        if let handedness {
            data[UserFields.handedness] = handedness
        }
        try await document.setData(data, merge: true)
    }

    func downloadProfile() async throws -> RemoteProfile? {
        guard let document = userDocument else { return nil }

        let snapshot = try await document.getDocument()
        guard let data = snapshot.data() else { return nil }

        return RemoteProfile(
            name: data[UserFields.name] as? String ?? "",
            email: data[UserFields.email] as? String ?? "",
            handedness: data[UserFields.handedness] as? String,
            streakCount: data[UserFields.streakCount] as? Int ?? 0,
            lastActivity: (data[UserFields.lastActivity] as? Timestamp)?.dateValue(),
            profileUpdatedAt: (data[UserFields.profileUpdatedAt] as? Timestamp)?.dateValue()
        )
    }
}
