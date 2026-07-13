//
//  AddWidgetsViews.swift
//  Talking Fingers
//
//  The add-widgets gallery: full-screen picker (iOS) and the preview cards
//  shared with the macOS sheet.
//

import SwiftUI

struct AddWidgetsScreen: View {
    var vm: ProfileWidgetsVM
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.availableWidgets, id: \.self) { type in
                        AddWidgetCardView(type: type, onAdd: {
                            vm.addWidget(type: type)
                        })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(TFColors.white.ignoresSafeArea())
    }

    private var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TFColors.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onDone) {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(TFColors.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TFColors.pill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("Add Widgets")
                .font(.headline)
                .foregroundStyle(TFColors.black)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(TFColors.white)
    }
}

struct AddWidgetCardView: View {
    let type: WidgetType
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundStyle(TFColors.black)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TFColors.gray)
                        .padding(7)
                        .background(TFColors.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(TFColors.border, lineWidth: 1)
                        )
                }

                // Content
                switch type {
                case .weeklyActivity:
                    WeeklyActivityPreview()
                case .accuracy:
                    AccuracyPreview()
                default:
                    EmptyView()
                }
            }
            .padding()
            .background(TFColors.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(TFColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

            // Plus button
            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(TFColors.controlGray)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
        }
    }
}

struct AccuracyPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            AccuracyRow(label: "Alphabet", percentage: 85)
            AccuracyRow(label: "Numbers", percentage: 93)
            AccuracyRow(label: "Greetings", percentage: 76)
            AccuracyRow(label: "Food", percentage: 66)

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
