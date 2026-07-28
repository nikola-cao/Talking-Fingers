//
//  OnboardingView.swift
//  Talking Fingers
//
//  Created by Jihoon Kim on 4/23/26.
//
//  Four-page onboarding flow shared by iOS and macOS: welcome, name +
//  handedness setup, fingerspelling intro, and camera practice.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AuthenticationViewModel.self) var authVM
    @State private var page = 0
    @State private var name = ""
    @State private var handedness: String? = nil
    let onFinished: (String, String?) -> Void
    init(onFinished: @escaping (String, String?) -> Void = { _, _ in }) {
        self.onFinished = onFinished
    }

    var body: some View {
        Group {
            switch page {
            case 0:
                ObWelcomeView { page = 1 }
            case 1:
                ObSetupView(onNext: { page = 2 }, name: $name, handedness: $handedness)
            case 2:
                ObFingerspellView(onNext: { page = 3 }, name: name)
            case 3:
                ObPracticeView(onNext: {
                    // Move to a terminal page before finishing to avoid re-entering this case
                    page = 4
                    // Call completion on the next runloop to let navigation update cleanly
                    DispatchQueue.main.async {
                        self.onFinished(self.name, self.handedness)
                    }
                }, name: name)
            default:
                EmptyView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            authVM.setSessionHandedness(handedness)
        }
        .onChange(of: handedness) { _, newValue in
            authVM.setSessionHandedness(newValue)
        }
    }
}

struct ObWelcomeView: View {
    let onNext: () -> Void
    var body: some View {
        ZStack {
            WelcomeGradientBackground()

            VStack(alignment: .leading) {
                ObWelcomeHeader()
                OnboardingPrimaryButton(title: "Get Started", action: onNext)
            }
            .frame(maxWidth: OnboardingStyle.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ObSetupView: View {
    let onNext: () -> Void
    enum Handedness {
        case left
        case right
    }
    @Binding var name: String
    @Binding var handedness: String?
    @State private var selectedHand: Handedness? = nil

    var body: some View {
        ScrollView {
            VStack {
                VStack(alignment: .leading) {
                    ObWelcomeHeader()
                }
                .frame(maxWidth: OnboardingStyle.contentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom)
                VStack(alignment: .leading) {
                    Text("Let's set you up.")
                        .font(.jakarta(size: 20, weight: .bold))
                        .foregroundColor(OnboardingStyle.textDark)
                        .padding(.bottom)
                    TextField("Your Name", text: $name)
                        .font(.jakarta(size: 17))
                        .disableAutocorrection(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray.opacity(0.1))
                        .border(OnboardingStyle.border)
                        .cornerRadius(12)
                        .padding(.bottom)
                    Text("In American Sign Language (ASL), dominant hand determines how you sign. ")
                        .font(.jakarta(size: 20, weight: .regular))
                        .foregroundColor(OnboardingStyle.textDark)
                    +
                    Text("Select your dominant hand.")
                        .font(.jakarta(size: 20, weight: .bold))
                        .foregroundColor(OnboardingStyle.textDark)
                    HStack(spacing: 8) {
                        SelectHandButton(title: "Left", imageName: "left", isSelected: selectedHand == .left) {
                            selectedHand = .left
                        }
                        SelectHandButton(title: "Right", imageName: "right", isSelected: selectedHand == .right) {
                            selectedHand = .right
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                    .padding(.top)

                    OnboardingPrimaryButton(title: "Start Learning", disabled: selectedHand == nil || name.isEmpty) {
                        if let hand = selectedHand {
                            handedness = hand == .left ? "left" : "right"
                        }
                        onNext()
                    }
                }
                .frame(maxWidth: OnboardingStyle.contentWidth, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ObFingerspellView: View {
    let onNext: () -> Void
    @State var name: String

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Nice to meet you,")
                        .font(.jakarta(size: 40, weight: .regular))
                        .foregroundColor(OnboardingStyle.textDark)
                    Text("\(name)!")
                        .font(.jakarta(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "#559AD2"))
                        .padding(.bottom)
                    Text("Learning to fingerspell is essential for your ASL journey. ")
                        .font(.jakarta(size: 20, weight: .regular))
                        .foregroundColor(OnboardingStyle.textDark)
                    +
                    Text("Let’s start with your name!")
                        .font(.jakarta(size: 20, weight: .bold))
                        .foregroundColor(OnboardingStyle.textDark)
                }
                .frame(maxWidth: OnboardingStyle.contentWidth, alignment: .leading)
                .padding(.bottom)
                .padding(.trailing)
                .padding(.leading)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom)

                VStack(alignment: .leading) {
                    ForEach(Array(name.lowercased()), id: \.self) { letter in
                        HStack {
                            Image("\(letter)")
                                .resizable()
                                .frame(width: 54, height: 72)
                            Text(letter.uppercased())
                                .font(.jakarta(size: 32, weight: .bold))
                                .foregroundColor(OnboardingStyle.textDark)
                            VStack {
                                Text(ASLSignDescriptions.description(for: letter))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .font(.jakarta(size: 16, weight: .regular))
                                    .foregroundColor(OnboardingStyle.textDark)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
                .frame(maxWidth: OnboardingStyle.contentWidth, alignment: .leading)
                .padding()

                OnboardingPrimaryButton(title: "Try It Out", action: onNext)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
