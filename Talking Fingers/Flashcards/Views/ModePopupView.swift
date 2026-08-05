//
//  ModePopupView.swift
//  Talking Fingers
//
//  Created by Sanvi Adusumilli on 3/12/26.
//

import SwiftUI

struct ModePopupView: View {
    
    @Binding var isPresented: Bool
    @State private var animatePopup = false
    
    var isExerciseUnlocked: Bool = true
    /// Share of the category's terms already seen in Learn, 0...100. Always
    /// shown — the popup only ever opens for a category, so a missing number
    /// would be a bug hiding itself.
    var learnPercentage: Int = 0
    /// Mastery across the category, which only Exercise can raise, 0...100.
    var exercisePercentage: Int = 0
    var onLearn: () -> Void
    var onExercise: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(animatePopup ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    closePopup()
                }
            
            VStack(spacing: 20) {
                
                Text("Select Mode")
                    .font(.jakartaTitle)
                    .fontWeight(.semibold)
                
#if os(macOS)
                VStack(spacing: 16) {
                    learnButton
                    exerciseButton
                }
#else
                HStack(spacing: 10) {
                    learnButton
                    exerciseButton
                }
#endif
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
            .frame(maxWidth: 560)
            
            .scaleEffect(animatePopup ? 1 : 0.85)
            .opacity(animatePopup ? 1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: animatePopup)
        }
        .onAppear {
            animatePopup = true
        }
    }
    
    private var learnButton: some View {
        modeButton(
            title: "Learn",
            imageName: "SentencesComprehendFlowerFull",
            background: Color(red: 0.678, green: 0.808, blue: 0.561, opacity: 0.3),
            border: Color(red: 0.678, green: 0.95, blue: 0.561),
            showLockHint: false,
            percentage: learnPercentage
        ) {
            onLearn()
            closePopup()
        }
    }
    
    private var exerciseButton: some View {
        modeButton(
            title: "Exercise",
            imageName: "SentencesSignFlowerFull",
            background: Color(red: 0.663, green: 0.808, blue: 0.985, opacity: isExerciseUnlocked ? 0.4 : 0.2),
            border: Color(red: 0.663, green: 0.85, blue: 0.925).opacity(isExerciseUnlocked ? 1.0 : 0.5),
            showLockHint: !isExerciseUnlocked,
            percentage: isExerciseUnlocked ? exercisePercentage : nil
        ) {
            onExercise()
            closePopup()
        }
        .disabled(!isExerciseUnlocked)
    }
    
    /// Shared card styling for the two mode buttons; macOS lays the card out
    /// horizontally, iOS vertically.
    private func modeButton(
        title: String,
        imageName: String,
        background: Color,
        border: Color,
        showLockHint: Bool,
        percentage: Int? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
#if os(macOS)
            HStack(spacing: 16) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.jakartaTitle)
                        .foregroundStyle(.black)

                    if showLockHint {
                        Text("Complete Learn first")
                            .font(.jakartaCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let percentage {
                    percentageLabel(percentage)
                        .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(border, lineWidth: 1.5)
            )
            .cornerRadius(24)
#else
            VStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                
                Text(title)
                    .font(.jakartaTitle2)
                    .foregroundStyle(.black)
                
                if showLockHint {
                    Text("Complete Learn first")
                        .font(.jakartaCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(background)
            .overlay(alignment: .topTrailing) {
                if let percentage {
                    percentageLabel(percentage)
                        .padding([.top, .trailing], 12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(border, lineWidth: 1.5)
            )
            .cornerRadius(24)
#endif
        }
        .buttonStyle(.plain)
    }
    
    private func percentageLabel(_ percentage: Int) -> some View {
        Text("\(percentage)%")
            .font(.jakarta(size: 16, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(percentage == 100 ? TFColors.deepGreen : .black.opacity(0.55))
            .accessibilityLabel("\(percentage) percent complete")
    }

    private func closePopup() {
        animatePopup = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        Text("Home Page")
            .font(.jakartaLargeTitle)
        
        ModePopupView(
            isPresented: .constant(true),
            isExerciseUnlocked: false,
            onLearn: {print("learn tapped")},
            onExercise: {print("exercise tapped")}
        )
    }
}
