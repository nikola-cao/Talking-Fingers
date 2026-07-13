//
//  FlowLayout.swift
//  Talking Fingers
//
//  Created by Krish Prasad on 3/15/26.
//
//  Wrapping flow layout: subviews fill each row left-to-right, wrapping to
//  a new row when the width is exceeded. Rows can be leading-aligned
//  (default), centered, or trailing-aligned within the available width.
//

import SwiftUI

public struct FlowLayout: Layout {
    var verticalSpacing: CGFloat
    var horizontalSpacing: CGFloat
    var alignment: HorizontalAlignment

    public init(
        verticalSpacing: CGFloat = 8,
        horizontalSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading
    ) {
        self.verticalSpacing = verticalSpacing
        self.horizontalSpacing = horizontalSpacing
        self.alignment = alignment
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var y: CGFloat = 0
    }

    private func computeRows(boundsWidth: CGFloat, proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.dimensions(in: proposal)

            if x > 0, x + size.width > boundsWidth {
                current.width = x - horizontalSpacing
                rows.append(current)
                y += current.height + verticalSpacing
                current = Row(y: y)
                x = 0
            }

            current.indices.append(index)
            current.height = max(current.height, size.height)
            current.y = y
            x += size.width + horizontalSpacing
        }

        if !current.indices.isEmpty {
            current.width = x - horizontalSpacing
            rows.append(current)
        }

        return rows
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        if let w = proposal.width, w > 0 {
            let rows = computeRows(boundsWidth: w, proposal: proposal, subviews: subviews)
            let h = rows.last.map { $0.y + $0.height } ?? 0
            return CGSize(width: w, height: h)
        }

        return proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = computeRows(boundsWidth: bounds.width, proposal: proposal, subviews: subviews)

        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center:
                x = bounds.minX + max(0, (bounds.width - row.width) / 2)
            case .trailing:
                x = bounds.minX + max(0, bounds.width - row.width)
            default:
                x = bounds.minX
            }

            for index in row.indices {
                let size = subviews[index].dimensions(in: proposal)
                subviews[index].place(
                    at: CGPoint(x: x + size.width / 2, y: bounds.minY + row.y + size.height / 2),
                    anchor: .center,
                    proposal: .unspecified
                )
                x += size.width + horizontalSpacing
            }
        }
    }
}
