import Foundation
import SwiftData

@Model
final class WidgetLayoutConfig {
    var widgetType: String
    var contextMode: String
    var size: String // "small", "medium", "large"
    var sortOrder: Int
    var isVisible: Bool
    var createdAt: Date

    init(
        widgetType: String,
        contextMode: String = "work",
        size: String = "medium",
        sortOrder: Int = 0,
        isVisible: Bool = true
    ) {
        self.widgetType = widgetType
        self.contextMode = contextMode
        self.size = size
        self.sortOrder = sortOrder
        self.isVisible = isVisible
        self.createdAt = Date()
    }

    enum WidgetType: String, CaseIterable {
        case calendar = "calendar"
        case weather = "weather"
        case priorities = "priorities"
        case energyScore = "energyScore"
        case quickStats = "quickStats"
        case teamPulse = "teamPulse"
        case familyCalendar = "familyCalendar"
        case mealPlan = "mealPlan"
    }

    enum WidgetSize: String, CaseIterable {
        case small = "small"
        case medium = "medium"
        case large = "large"
    }
}
