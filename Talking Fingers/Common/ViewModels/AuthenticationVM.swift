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
    var isLoggedIn = false
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
                    await self.loadCurrentUserProfile(for: user, isLoggingIn: false)
                }
            } else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isLoggedIn = false
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
    
    public var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
    
    func login(email: String, password: String) async {
        isLoading = true
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

            var userData: [String: Any] = [
                "userId": newUser.userId,
                "name": newUser.name,
                "email": newUser.email,
                "streakCount": 0,
                "profileUpdatedAt": Timestamp(date: Date())
            ]
            if let normalizedHandedness {
                userData["handedness"] = normalizedHandedness
            }
            do {
                try await Firebase.db.collection("Users").document(newUser.userId).setData(userData)
            } catch {
                // Profile doc is re-uploaded by the next profile sync; don't block sign-in on it.
                print("Error saving user profile: \(error)")
            }

            await MainActor.run {
                self.currentUser = newUser
                self.sessionHandedness = newUser.handedness
                self.isLoggedIn = true
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
                self.isLoggedIn = false
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

    private func loadCurrentUserProfile(for authUser: FirebaseAuth.User, fallbackEmail: String? = nil, isLoggingIn: Bool) async {
        do {
            let document = try await Firebase.db.collection("Users").document(authUser.uid).getDocument()
            let data = document.data()
            let handedness = normalizeHandedness(data?["handedness"] as? String)

            let hydratedUser = User(
                userId: authUser.uid,
                name: (data?["name"] as? String) ?? authUser.displayName ?? "",
                email: (data?["email"] as? String) ?? authUser.email ?? fallbackEmail ?? "",
                handedness: handedness
            )
            hydratedUser.streakCount = data?["streakCount"] as? Int ?? 0
            hydratedUser.lastActivity = (data?["lastActivity"] as? Timestamp)?.dateValue()
            hydratedUser.profileUpdatedAt = (data?["profileUpdatedAt"] as? Timestamp)?.dateValue()

            DispatchQueue.main.async {
                self.currentUser = hydratedUser
                self.sessionHandedness = handedness
                self.isLoggedIn = true
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
                self.isLoggedIn = true
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
