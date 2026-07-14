//
//  CameraVM+Thresholds.swift
//  Talking Fingers
//

import Foundation

extension CameraVM {
    /// Thresholds for the Good / Okay / Bad bands used by the developer
    /// camera tool (CameraView), relaxed proportionally to the loaded
    /// reference's kinematic complexity (wrist path length, from
    /// `referenceComplexity`).
    ///
    /// DTW on long-travel signs accumulates more 2D alignment error per frame
    /// just by virtue of covering more pixels; a perfect performance of such
    /// a sign caps lower than a tight planar sign. The shift is single-
    /// direction (negative only) — complexity can only relax the thresholds,
    /// never tighten them — because path length is a "cost" signal, not a
    /// "precision" one.
    ///
    /// Max shift is 8 pts at complexity = 1 (`pathLength >= 0.20`), giving
    /// a dynamic-sign Good threshold range of 62..70.
    var complexityAdjustedThresholds: (good: Double, okay: Double) {
        let isStatic = activeComparisonType == .static
        let baseGood: Double = isStatic ? 80 : 70
        let baseOkay: Double = isStatic ? 60 : 51

        let shift = -referenceComplexity * 8

        return (good: baseGood + shift, okay: baseOkay + shift)
    }
}
