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

    private let db = Firestore.firestore()

    private var userDocument: DocumentReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("Users").document(uid)
    }

    func uploadProfile(for user: User) async throws {
        guard let document = userDocument else { return }

        var data: [String: Any] = [
            "userId": user.userId,
            "name": user.name,
            "email": user.email,
            "streakCount": user.streakCount,
            "profileUpdatedAt": Timestamp(date: user.profileUpdatedAt ?? Date())
        ]
        if let handedness = user.handedness {
            data["handedness"] = handedness
        }
        if let lastActivity = user.lastActivity {
            data["lastActivity"] = Timestamp(date: lastActivity)
        }
        try await document.setData(data, merge: true)
    }

    func uploadHandedness(_ handedness: String?) async throws {
        guard let document = userDocument else { return }
        var data: [String: Any] = [
            "profileUpdatedAt": Timestamp(date: Date())
        ]
        if let handedness {
            data["handedness"] = handedness
        }
        try await document.setData(data, merge: true)
    }

    func downloadProfile() async throws -> RemoteProfile? {
        guard let document = userDocument else { return nil }

        let snapshot = try await document.getDocument()
        guard let data = snapshot.data() else { return nil }

        return RemoteProfile(
            name: data["name"] as? String ?? "",
            email: data["email"] as? String ?? "",
            handedness: data["handedness"] as? String,
            streakCount: data["streakCount"] as? Int ?? 0,
            lastActivity: (data["lastActivity"] as? Timestamp)?.dateValue(),
            profileUpdatedAt: (data["profileUpdatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
