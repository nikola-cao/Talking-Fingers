//
//  AnalyticsModel.swift
//  Talking Fingers
//
//  Created by Ilisha Gupta on 24/02/26.
//

import Foundation
import SwiftData

@Model
class AnalyticsModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Float

    init(date: Date, value: Float) {
        self.id = UUID()
        self.date = date
        self.value = value
    }
}
