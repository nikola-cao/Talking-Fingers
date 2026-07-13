//
//  WidgetContents.swift
//  Talking Fingers
//
//  Content views for the profile widgets (streak, words learned, progress,
//  daily challenge, mastery badges, accuracy).
//

import SwiftUI
import SwiftData

struct StreakWidgetContent: View {
    @Query private var users: [User]

    private var streakCount: Int {
        users.first?.streakCount ?? 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(TFColors.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(streakCount)")
                    .font(.system(size: 28, weight: .bold))
                    .fontWeight(.bold)
                Text(streakCount == 1 ? "day in a row" : "days in a row")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(TFColors.darkerGray)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WordsLearnedWidgetContent: View {
    @Environment(SwiftDataVM.self) private var dataVM

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(TFColors.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(dataVM.wordsLearnedCount())")
                    .font(.system(size: 28, weight: .bold))
                    .fontWeight(.bold)
                Text("words learned")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(TFColors.darkerGray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentProgressWidgetContent: View {
    @Environment(SwiftDataVM.self) private var dataVM

    private var masteryPercentage: Int {
        Int(dataVM.masteryPercentage(for: dataVM.fetchFlashcards()).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "medal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TFColors.lightBlue)
                Text("Overall Mastery")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(TFColors.textMuted)
                Spacer()
            }

            HStack(spacing: 10) {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h: CGFloat = 10
                    let progress = CGFloat(masteryPercentage) / 100
                    let fillW = max(0, w * progress)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(TFColors.trackBlue)
                        Capsule()
                            .fill(TFColors.blue)
                            .frame(width: fillW)
                    }
                    .frame(height: h)
                }
                .frame(height: 10)

                Text("\(masteryPercentage)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFColors.black)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct DailyChallengeWidgetContent: View {
    @Environment(SwiftDataVM.self) private var dataVM

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let practiced = dataVM.practicedDaysThisWeek().contains(index)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(practiced ? TFColors.paleGreen : TFColors.badgeLockedBg)
                                .overlay(
                                    Circle()
                                        .stroke(practiced ? TFColors.green : TFColors.gray, lineWidth: 1.2)
                                )
                                .frame(width: 34, height: 34)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(practiced ? TFColors.green : TFColors.gray)
                        }
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TFColors.darkerGray)
                    }
                }
            }
        }
    }
}

struct MasteryBadgesWidgetContent: View {
    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 2
            let interItem: CGFloat = 10
            let columns: CGFloat = 4
            let usableWidth = max(0, proxy.size.width - horizontalPadding * 2 - interItem * (columns - 1))
            // Cap tile size so two rows + labels don't overflow at wide macOS windows.
            let side = min(floor(usableWidth / columns), 100)

            VStack(spacing: 14) {
                HStack(spacing: interItem) {
                    MasteryBadgeItem(isLocked: false, side: side)
                    MasteryBadgeItem(isLocked: false, side: side)
                    MasteryBadgeItem(isLocked: false, side: side)
                    MasteryBadgeItem(isLocked: false, side: side)
                }
                HStack(spacing: interItem) {
                    MasteryBadgeItem(isLocked: false, side: side)
                    MasteryBadgeItem(isLocked: true, side: side)
                    MasteryBadgeItem(isLocked: true, side: side)
                    MasteryBadgeItem(isLocked: true, side: side)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 6)
        }
        .frame(minHeight: 198)
    }
}

struct MasteryBadgeItem: View {
    let isLocked: Bool
    let side: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLocked ? TFColors.badgeLockedBg : TFColors.paleGold)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isLocked ? TFColors.gray : TFColors.gold, lineWidth: 1)
                    )
                    .frame(width: side, height: side)

                Image(systemName: isLocked ? "lock.fill" : "trophy")
                    .font(.system(size: min(22, side * 0.42), weight: .semibold))
                    .foregroundStyle(isLocked ? TFColors.textDark : TFColors.gold)
            }
            Text("Name")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(TFColors.textMuted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AccuracyWidgetContent: View {
    @Environment(SwiftDataVM.self) private var dataVM

    private var rows: [(label: String, percentage: Int)] {
        let stats = dataVM.accuracyByCategory()
        if stats.isEmpty {
            return [(label: "No data yet", percentage: 0)]
        }
        return stats.map { ($0.category.displayName, $0.percentage) }
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    AccuracyRow(label: row.label, percentage: row.percentage)
                }
            }

            HStack(alignment: .center) {
                Text("Review Again?")
                    .font(.subheadline)
                    .foregroundStyle(TFColors.black)
                Spacer()
                Button(action: {}) {
                    Text("Practice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TFColors.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TFColors.practiceGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AccuracyRow: View {
    let label: String
    let percentage: Int

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(TFColors.textDark)
                .frame(width: 92, alignment: .leading)

            GeometryReader { proxy in
                let w = proxy.size.width
                let h: CGFloat = 10
                let fillW = max(0, w * CGFloat(percentage) / 100)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(TFColors.chartPlotFill)
                    Capsule()
                        .fill(TFColors.blue)
                        .frame(width: fillW)
                }
                .frame(height: h)
                .overlay(
                    Capsule()
                        .stroke(TFColors.chartBarStroke.opacity(0.35), lineWidth: 1)
                )
            }
            .frame(height: 10)

            Text("\(percentage)%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TFColors.textMuted)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
