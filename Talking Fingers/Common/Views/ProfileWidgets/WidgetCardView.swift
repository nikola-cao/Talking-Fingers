//
//  WidgetCardView.swift
//  Talking Fingers
//
//  Card chrome shared by every profile widget: title row, remove button,
//  and the edit-mode wiggle.
//

import SwiftUI
import SwiftData

struct WidgetCardView: View {
    let widget: ProfileWidget
    let isEditMode: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                if !widgetTitle.isEmpty {
                    HStack {
                        Text(widgetTitle)
                            .font(.headline)
                            .foregroundStyle(TFColors.black)
                        Spacer()
                        if widget.type == .dailyChallenge {
                            DailyChallengeHeaderTrailing()
                        } else if showsAccessory {
                            Image(systemName: accessoryIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(widget.type == .masteryBadges ? TFColors.gray : TFColors.iconGray)
                                .padding(7)
                                .background(widget.type == .masteryBadges ? TFColors.white : TFColors.pill)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(TFColors.border, lineWidth: 1)
                                )
                        }
                    }
                }

                // Content
                switch widget.type {
                case .streak:
                    StreakWidgetContent()
                case .wordsLearned:
                    WordsLearnedWidgetContent()
                case .recentProgress:
                    RecentProgressWidgetContent()
                case .dailyChallenge:
                    DailyChallengeWidgetContent()
                case .masteryBadges:
                    MasteryBadgesWidgetContent()
                case .weeklyActivity:
                    WeeklyActivityWidgetContent()
                case .accuracy:
                    AccuracyWidgetContent()
                }
            }
            .padding(widgetTitle.isEmpty ? 14 : 16)
            .background(TFColors.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(TFColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

            // Remove button
            if isEditMode && isRemovable {
                Button(action: onRemove) {
                    ZStack {
                        Circle()
                            .fill(TFColors.controlGray)
                            .frame(width: 24, height: 24)
                        Image(systemName: "minus")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: -8)
            }
        }
        .modifier(WidgetWiggleModifier(isActive: isEditMode))
    }

    private var isRemovable: Bool {
        true
    }

    private var showsAccessory: Bool {
        widget.type == .weeklyActivity || widget.type == .accuracy || widget.type == .masteryBadges
    }

    private var accessoryIcon: String {
        switch widget.type {
        case .weeklyActivity, .accuracy, .masteryBadges:
            return "chevron.right"
        default:
            return "chevron.right"
        }
    }

    private var widgetTitle: String {
        switch widget.type {
        case .wordsLearned:
            return ""
        case .recentProgress:
            return "Recent Progress"
        case .dailyChallenge:
            return "Daily Challenge"
        case .masteryBadges:
            return "Mastery Badges"
        case .weeklyActivity:
            return "Weekly Activity"
        case .accuracy:
            return "Accuracy"
        case .streak:
            return ""
        }
    }
}

// Home-screen style jiggle applied to each widget card while edit mode is on.
// Small per-widget phase offset keeps neighbours out of sync.
struct WidgetWiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .task(id: isActive) {
                if isActive {
                    angle = Double.random(in: 0.2...0.4)
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 0...120_000_000))
                    guard !Task.isCancelled else { return }
                    withAnimation(
                        .easeInOut(duration: 0.15)
                            .repeatForever(autoreverses: true)
                    ) {
                        angle = -0.4
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { angle = 0 }
                }
            }
    }
}

private struct DailyChallengeHeaderTrailing: View {
    @Query private var users: [User]

    private var streakLabel: String {
        let count = users.first?.streakCount ?? 0
        return count == 1 ? "1 Day Streak" : "\(count) Day Streak"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TFColors.gold)
            Text(streakLabel)
                .font(.subheadline)
                .foregroundStyle(TFColors.black)
        }
    }
}
