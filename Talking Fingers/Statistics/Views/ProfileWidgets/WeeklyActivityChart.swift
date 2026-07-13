//
//  WeeklyActivityChart.swift
//  Talking Fingers
//
//  Bar chart of practice attempts per day, plus the widget content and
//  the static preview used in the add-widgets gallery.
//

import SwiftUI

struct WeeklyActivityWidgetContent: View {
    @Environment(SwiftDataVM.self) private var dataVM

    var body: some View {
        WeeklyActivityChartView(minutes: dataVM.weeklyAttemptCounts())
    }
}

struct WeeklyActivityPreview: View {
    var body: some View {
        WeeklyActivityChartView(minutes: [35, 30, 10, 52, 35, 12, 30])
    }
}

private struct WeeklyActivityChartView: View {
    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    let minutes: [Int]
    private let yTicks = [60, 45, 30, 15, 0]

    private var maxValue: Int {
        max(minutes.max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("time")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFColors.textMuted)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                Text("(attempts)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TFColors.textMuted)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .padding(.top, 2)
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TFColors.chartPlotFill.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(TFColors.border, lineWidth: 1)
                        )

                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(yTicks, id: \.self) { tick in
                                Text("\(tick)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(TFColors.textMuted)
                                    .frame(height: chartInnerHeight / CGFloat(yTicks.count - 1), alignment: .top)
                            }
                        }
                        .frame(width: 30, alignment: .trailing)
                        .padding(.leading, 6)
                        .padding(.top, 6)

                        VStack(spacing: 0) {
                            ForEach(0..<(yTicks.count - 1), id: \.self) { _ in
                                Rectangle()
                                    .fill(TFColors.gray.opacity(0.25))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 6)
                                    .frame(height: chartInnerHeight / CGFloat(yTicks.count - 1), alignment: .top)
                            }
                        }
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(days.indices, id: \.self) { index in
                            let value = index < minutes.count ? minutes[index] : 0
                            let barH = max(6, chartInnerHeight * CGFloat(value) / CGFloat(max(maxValue, yTicks.first ?? 1)))

                            VStack(spacing: 8) {
                                Spacer(minLength: 0)

                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(TFColors.lightBlue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(TFColors.chartBarStroke, lineWidth: 1)
                                    )
                                    .frame(height: barH)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.trailing, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 26)
                }
                .frame(height: chartOuterHeight)

                HStack(spacing: 8) {
                    ForEach(days.indices, id: \.self) { index in
                        Text(days[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TFColors.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private var chartOuterHeight: CGFloat { 170 }
    private var chartInnerHeight: CGFloat { chartOuterHeight - 32 }
}
