//
//  EndCardComponent.swift
//  Talking Fingers
//
//  Created by Sanvi Adusumilli on 4/16/26.
//

import SwiftUI

struct EndCardComponent: View {
    let context: StartContext
    let total: Int
    let onGoHome: () -> Void
    let onGoToExercise: () -> Void
    
    #if os(macOS)
    private let verticalStackSpacing: CGFloat = 34
    private let sectionGap: CGFloat = 18
    private let buttonVerticalPadding: CGFloat = 20
    private let contentVerticalPadding: CGFloat = 28
    private let bottomSpacerHeight: CGFloat = 58
    #else
    private let verticalStackSpacing: CGFloat = 24
    private let sectionGap: CGFloat = 10
    private let buttonVerticalPadding: CGFloat = 16
    private let contentVerticalPadding: CGFloat = 0
    private let bottomSpacerHeight: CGFloat = 40
    #endif
    
    var body: some View {
        VStack(spacing: verticalStackSpacing) {
            let isLearnMode = context.isLearn
            
            Spacer()
            
            if case .dailyChallenge = context {
                ZStack {
                    Image(systemName: "flame.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundColor(Color(red: 0.96, green: 0.76, blue: 0.28))
                    
                    // can have actual streak later:
//                    Text("3")
//                        .font(.system(size: 45, weight: .bold))
//                        .foregroundColor(.white)
//                        .padding(.top, 25)
                }
            } else {
                Image(systemName: context.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .foregroundColor(isLearnMode ? TFColors.lightGreen : .black)
            }
            
            if case .learn(let cat) = context {
                Text("\(cat.displayName) Exercise")
                    .font(.jakarta(size: 32))
                    .foregroundColor(.black.opacity(0.7))
                
                Text("Unlocked!")
                    .font(.jakarta(size: 35, weight: .bold))
                    .foregroundColor(TFColors.sandGold)
                
            } else {
                Text("Congrats!")
                    .font(.jakarta(size: 36, weight: .bold))
                
                if case .exercise(let cat) = context {
                    VStack(spacing: 10) {
                        Text("You have completed")
                            .font(.jakarta(size: 31))
                            .foregroundColor(.black.opacity(0.8))
                        Text("\(cat.displayName)!")
                            .font(.jakarta(size: 31, weight: .bold))
                            .foregroundColor(TFColors.sandGold)
                    }
                }
                
                Spacer().frame(height: sectionGap)
                
                Text("\(total)/\(total) Words Completed")
                    .font(.jakartaSubheadline)
                    .foregroundColor(.black.opacity(0.8))
                
                ProgressView(value: 1.0)
                    .tint(TFColors.tabBlue)
                    .scaleEffect(y: 1.5)
                    .padding(.horizontal, 60)
            }
            
            Spacer()
            
            if case .learn = context {
                Button(action: onGoToExercise) {
                    Text("Go to Exercise")
                        .font(.jakartaHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, buttonVerticalPadding)
                        .background(RoundedRectangle(cornerRadius: 16).fill(TFColors.lightGreen))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
            
            Button(action: onGoHome) {
                let myColor = TFColors.darkGreenText
                Text("Go Home")
                    .font(.jakartaHeadline)
                    .foregroundColor(isLearnMode ? myColor : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, buttonVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isLearnMode ? TFColors.lightGreen.opacity(0.25) : TFColors.lightGreen)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            
            Spacer().frame(height: bottomSpacerHeight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, contentVerticalPadding)
    }
}
