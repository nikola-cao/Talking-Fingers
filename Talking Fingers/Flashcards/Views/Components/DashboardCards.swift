//
//  DashboardCards.swift
//  Talking Fingers
//
//  Card components used by the dashboard's "Jump back in" and
//  "Daily Challenge" sections on both platforms.
//

import SwiftUI

// MARK: - In Progress Card

struct InProgressCard: View {
    let category: TermCategory
    let mode: String
    let progress: Float
    let backgroundColor: Color
    let borderColor: Color

    var body: some View {
        VStack(spacing: 12) {

            Spacer(minLength: 0)

            Image(systemName: category.iconName)
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .foregroundColor(borderColor)

            VStack(spacing: 4) {
                Text("Continue \(mode)")
                    .font(.jakarta(size: 15))
                    .foregroundStyle(.secondary)

                Text(category.displayName.capitalized)
                    .font(.jakarta(size: 20))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(borderColor)

            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.6))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.45, green: 0.65, blue: 0.25))
                            .frame(width: geo.size.width * CGFloat(progress / 100))
                    }
                }
                .frame(height: 8)

                Text("\(Int(progress))%")
                    .font(.jakarta(size: 12))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(backgroundColor)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Daily Challenge Card

struct DailyChallengeCard: View {
    let streak: Int
    let completed: Int
    let total: Int

    var progress: CGFloat {
        CGFloat(Double(completed) / Double(max(total, 1)))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(TFColors.challengeGold)
                    Text("\(streak) Day Streak")
                        .font(.jakarta(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(red: 0.98, green: 0.88, blue: 0.65))
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Practice Missed Signs")
                        .font(.jakarta(size: 22))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))

                    Text("+20XP")
                        .font(.jakarta(size: 15))
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.8))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.7))

                        Capsule()
                            .fill(TFColors.tabBlue)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)
            }

            Spacer()

            Image(systemName: "medal.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 65)
                .foregroundColor(TFColors.challengeGold)
                .padding(.trailing, 8)
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.95, blue: 0.86))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color(red: 0.963, green: 0.86, blue: 0.609), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
