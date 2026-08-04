//
//  AuthenticationViewModel.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 1/27/26.
//

@preconcurrency import FirebaseAuth
import FirebaseFirestore
import Observation

@Observable
class AuthenticationViewModel {
    var errorMessage: String?
    var isLoading = false
    var isInitializingSession = true
    var currentUser: User?
    var sessionHandedness: String?
    var auth: Auth
    private var handler: AuthStateDidChangeListenerHandle?

    var effectiveHandedness: String? {
        currentUser?.handedness ?? sessionHandedness
    }

    init() {
        self.auth = Auth.auth()
        self.handler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            if let user = user {
                // An explicit login/register flow is already hydrating the profile;
                // loading here too would race it and clobber its result.
                guard !self.isLoading else { return }
                Task {
                    // A keychain-cached session can outlive the account (e.g. the
                    // user was deleted in the Firebase console). Confirm it still
                    // exists server-side before restoring the session.
                    guard await self.restoredSessionIsValid(user) else {
                        try? self.auth.signOut()
                        return
                    }
                    await self.loadCurrentUserProfile(for: user, isLoggingIn: false)
                }
            } else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isInitializingSession = false
                    self.sessionHandedness = nil
                }
            }
        }
    }
    
    deinit {
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            await loadCurrentUserProfile(for: authResult.user, fallbackEmail: email, isLoggingIn: true)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func register(email: String, password: String, name: String, handedness: String? = nil) async {
        isLoading = true
        errorMessage = nil
        let normalizedHandedness = normalizeHandedness(handedness)
        sessionHandedness = normalizedHandedness

        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let authUser = result.user

            let changeRequest = authUser.createProfileChangeRequest()
            changeRequest.displayName = name
            do {
                try await changeRequest.commitChanges()
            } catch {
                print("Failed to set displayName: \(error.localizedDescription)")
            }

            let newUser = User(userId: authUser.uid, name: name, email: email, handedness: normalizedHandedness)
            newUser.profileUpdatedAt = Date()
            newUser.needsProfileSync = true

            do {
                // Force the ID token before the first write. Firestore picks up
                // a brand-new session's credentials asynchronously, and a write
                // issued before that lands is rejected as unauthenticated
                // ("Missing or insufficient permissions") even under correct rules.
                _ = try? await authUser.getIDTokenResult(forcingRefresh: true)

                // Writes the same fields the manual payload used to
                // (userId/name/email/streakCount 0/profileUpdatedAt now,
                // + handedness when set).
                try await UserProfileService().uploadProfile(for: newUser)
                newUser.needsProfileSync = false
            } catch {
                // Stays flagged so SwiftDataVM.syncAuthenticatedUser retries it
                // moments later; don't block sign-in on it.
                print("Error saving user profile, will retry on next sync: \(error)")
            }

            await MainActor.run {
                self.currentUser = newUser
                self.sessionHandedness = newUser.handedness
                self.isLoading = false
                self.isInitializingSession = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.sessionHandedness = nil
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func setSessionHandedness(_ handedness: String?) {
        let normalized = normalizeHandedness(handedness)
        sessionHandedness = normalized
        currentUser?.handedness = normalized
        Task {
            do {
                try await UserProfileService().uploadHandedness(normalized)
            } catch {
                print("Failed to upload handedness: \(error)")
            }
        }
    }

    /// Checks with the Firebase servers that a keychain-restored user still
    /// exists and is enabled. Transient failures (e.g. offline) keep the
    /// cached session so the app still works without a connection.
    private func restoredSessionIsValid(_ user: FirebaseAuth.User) async -> Bool {
        do {
            try await user.reload()
            return true
        } catch {
            switch AuthErrorCode(rawValue: (error as NSError).code) {
            case .userNotFound, .userDisabled, .userTokenExpired, .invalidUserToken, .invalidCredential:
                return false
            default:
                return true
            }
        }
    }

    private func loadCurrentUserProfile(for authUser: FirebaseAuth.User, fallbackEmail: String? = nil, isLoggingIn: Bool) async {
        do {
            let document = try await Firebase.users.document(authUser.uid).getDocument()
            let data = document.data()
            let handedness = normalizeHandedness(data?[UserFields.handedness] as? String)

            let hydratedUser = User(
                userId: authUser.uid,
                name: (data?[UserFields.name] as? String) ?? authUser.displayName ?? "",
                email: (data?[UserFields.email] as? String) ?? authUser.email ?? fallbackEmail ?? "",
                handedness: handedness
            )
            hydratedUser.streakCount = data?[UserFields.streakCount] as? Int ?? 0
            hydratedUser.lastActivity = (data?[UserFields.lastActivity] as? Timestamp)?.dateValue()
            hydratedUser.profileUpdatedAt = (data?[UserFields.profileUpdatedAt] as? Timestamp)?.dateValue()

            DispatchQueue.main.async {
                self.currentUser = hydratedUser
                self.sessionHandedness = handedness
                self.isLoading = false
                self.isInitializingSession = false
                if isLoggingIn {
                    print("Signed in as \(authUser.uid)")
                }
            }
        } catch {
            print("Failed to load user profile: \(error.localizedDescription)")

            let fallbackUser = User(
                userId: authUser.uid,
                name: authUser.displayName ?? "",
                email: authUser.email ?? fallbackEmail ?? ""
            )

            DispatchQueue.main.async {
                self.currentUser = fallbackUser
                self.sessionHandedness = self.normalizeHandedness(self.sessionHandedness)
                self.isLoading = false
                self.isInitializingSession = false
                if isLoggingIn {
                    print("Signed in as \(authUser.uid)")
                }
            }
        }
    }

    private func normalizeHandedness(_ handedness: String?) -> String? {
        guard let normalized = handedness?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              normalized == "left" || normalized == "right" else {
            return nil
        }
        return normalized
    }
}
