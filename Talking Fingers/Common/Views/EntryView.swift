//
//  EntryView.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 1/27/26.
//

import Foundation
import SwiftUI

struct EntryView: View {
    @State private var isLogin: Bool = true
    @State private var showOnboarding: Bool = false
    @State private var pushOnboarding: Bool = false
    @State private var pendingEmail: String = ""
    @State private var pendingPassword: String = ""
    @Environment(AuthenticationViewModel.self) var authVM
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: {
                        self.isLogin = true
                        authVM.errorMessage = nil
                    }) {
                        VStack(spacing: 8) {
                            if (isLogin) {
                                Text("Login")
                                    .foregroundColor(Color.black)
                            } else {
                                Text("Login")
                                    .foregroundColor(Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .padding()
                    Button(action: {
                        self.isLogin = false
                        authVM.errorMessage = nil
                    }) {
                        VStack(spacing: 8) {
                            if (isLogin) {
                                Text("Register")
                                    .foregroundColor(Color.gray.opacity(0.3))
                            } else {
                                Text("Register")
                                    .foregroundColor(Color.black)
                            }
                        }
                    }
                    .padding()
                }
                if (isLogin) {
                    Login()
                } else {
                    Register(onSuccess: { email, password in
                        // After successful register, present onboarding first
                        pendingEmail = email
                        pendingPassword = password
                        pushOnboarding = true
                    })
                }
            }
            .background(
                NavigationLink(isActive: $pushOnboarding) {
                    OnboardingView(onFinished: { name, handedness in
                        // Registration signs the user in and hydrates the session itself.
                        Task {
                            authVM.setSessionHandedness(handedness)
                            await authVM.register(email: pendingEmail, password: pendingPassword, name: name, handedness: handedness)
                            // On failure, pop back to the register form so the error is visible.
                            if authVM.errorMessage != nil {
                                pushOnboarding = false
                                isLogin = false
                            }
                        }
                    })
                } label: {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

struct Login: View {
    @Environment(AuthenticationViewModel.self) var authVM
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        VStack {
            TextField("Email", text: $email)

                .universalAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
            SecureField("Password", text: $password)
                #if !os(macOS)
                .textContentType(.oneTimeCode)
                #endif

                .universalAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
            if let errorMessage = authVM.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button(action: {
                Task {
                    await authVM.login(email: email, password: password)
                }
            }) {
                if authVM.isLoading {
                    Text("Loading...")
                } else {
                    Text("Log In")
                }
            }
            .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)
        }
        .padding()

    }
}

struct Register: View {
    @Environment(AuthenticationViewModel.self) var authVM
    let onSuccess: (_ email: String, _ password: String) -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var validationMessage: String?
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .universalAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
            SecureField("Password", text: $password)
                #if !os(macOS)
                .textContentType(.none)
                #endif

                .universalAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
            SecureField("Confirm Password", text: $passwordConfirm)
                #if !os(macOS)
                .textContentType(.none)
                #endif

                .universalAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
            if let message = validationMessage ?? authVM.errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button(action: {
                guard let trimmedEmail = validate() else { return }
                // Defer registration until after onboarding completes
                onSuccess(trimmedEmail, password)
            }) {
                if authVM.isLoading {
                    Text("Loading...")
                } else {
                    Text("Register")
                }
            }
            .disabled(authVM.isLoading)

        }
        .padding()
    }

    /// Returns the trimmed email if all fields pass, nil otherwise.
    private func validate() -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            validationMessage = "Please enter a valid email address."
            return nil
        }
        // Firebase Auth requires at least 6 characters.
        if password.count < 6 {
            validationMessage = "Password must be at least 6 characters."
            return nil
        }
        if password != passwordConfirm {
            validationMessage = "Passwords don't match."
            return nil
        }
        validationMessage = nil
        return trimmedEmail
    }
}
