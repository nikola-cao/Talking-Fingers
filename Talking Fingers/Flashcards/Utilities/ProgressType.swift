//
//  ProgressType.swift
//  Talking Fingers
//
//  Created by Isha Jain on 1/29/26.
//

import Foundation

enum ProgressType: String, Codable, Comparable {
    case new
    case learning
    case polishing
    case mastered

    /// Position along the progression, so callers can compare and cap.
    var rank: Int {
        switch self {
        case .new:       return 0
        case .learning:  return 1
        case .polishing: return 2
        case .mastered:  return 3
        }
    }

    static func < (lhs: ProgressType, rhs: ProgressType) -> Bool {
        lhs.rank < rhs.rank
    }

    func increase() -> ProgressType {
        switch self {
        case .new: return .learning
        case .learning: return .polishing
        case .polishing: return .mastered
        case .mastered: return .mastered
        }
    }

    func decrease() -> ProgressType {
        switch self {
        case .new: return .new
        case .learning: return .new
        case .polishing: return .learning
        case .mastered: return .polishing
        }
    }
}
