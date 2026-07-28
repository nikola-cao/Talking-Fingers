//
//  ProfileShared.swift
//  Talking Fingers
//
//  Pieces shared by the iOS (ProfileWidgetsView) and macOS (MacProfileView)
//  profile pages: the widget row-pairing model, the Edit/Add/Done action row,
//  the log-out button, and the widget card chrome.
//

import SwiftUI

// MARK: - Widget row pairing

/// A display row of profile widgets: either one full-width widget or the
/// small streak/words-learned cards paired side by side.
struct ProfileWidgetRow: Identifiable {
    enum Kind {
        case single(ProfileWidget)
        case pair(ProfileWidget, ProfileWidget)
    }

    let id: String
    let kind: Kind
}

/// Groups a flat widget list into display rows. `pairEitherOrder` also pairs
/// words-learned followed by streak (macOS column behavior); iOS pairs only
/// streak-then-words-learned.
func buildProfileWidgetRows(from widgets: [ProfileWidget], pairEitherOrder: Bool) -> [ProfileWidgetRow] {
    var rows: [ProfileWidgetRow] = []
    var i = 0

    while i < widgets.count {
        let w = widgets[i]
        let next = i + 1 < widgets.count ? widgets[i + 1] : nil

        let pairsWithNext = next.map { n in
            (w.type == .streak && n.type == .wordsLearned) ||
            (pairEitherOrder && w.type == .wordsLearned && n.type == .streak)
        } ?? false

        if pairsWithNext, let n = next {
            rows.append(ProfileWidgetRow(
                id: "pair:\(w.id.uuidString):\(n.id.uuidString)",
                kind: .pair(w, n)
            ))
            i += 2
        } else {
            rows.append(ProfileWidgetRow(id: "single:\(w.id.uuidString)", kind: .single(w)))
            i += 1
        }
    }

    return rows
}

// MARK: - Action row (Edit Widgets / Add Widgets / Done + date)

struct ProfilePillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            #if os(macOS)
            Text(title)
                .font(.jakarta(size: 13, weight: .semibold))
                .foregroundStyle(TFColors.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(TFColors.pill)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(TFColors.border, lineWidth: 1)
                )
            #else
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(TFColors.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(TFColors.pill)
                .clipShape(Capsule())
            #endif
        }
        .buttonStyle(.plain)
    }
}

struct ProfileActionRow: View {
    let isEditing: Bool
    let onAdd: () -> Void
    let onDone: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            if isEditing {
                ProfilePillButton(title: "Add Widgets", action: onAdd)
                Spacer()
                ProfilePillButton(title: "Done", action: onDone)
            } else {
                ProfilePillButton(title: "Edit Widgets", action: onEdit)
                Spacer()
                Text(formattedToday)
                    #if os(macOS)
                    .font(.jakarta(size: 14, weight: .semibold))
                    .foregroundStyle(TFColors.textDark)
                    #else
                    .font(.subheadline)
                    .foregroundStyle(TFColors.darkerGray)
                    #endif
            }
        }
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Log out

struct ProfileLogOutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Log Out")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TFColors.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card chrome

extension View {
    /// White rounded card with hairline border and soft shadow used by the
    /// profile widget and add-widget cards.
    func profileCardChrome() -> some View {
        self
            .background(TFColors.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(TFColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
