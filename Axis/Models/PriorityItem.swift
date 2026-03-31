import Foundation
import SwiftData

@Model
final class PriorityItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var sourceModule: String = ""
    var timeEstimateMinutes: Int = 0
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var contextMode: String = ""
    var dueDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()
    var completedAt: Date?

    init(
        title: String,
        sourceModule: String = "commandCenter",
        timeEstimateMinutes: Int = 30,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        contextMode: String = "work",
        dueDate: Date? = nil,
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.title = title
        self.sourceModule = sourceModule
        self.timeEstimateMinutes = timeEstimateMinutes
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.contextMode = contextMode
        self.dueDate = dueDate
        self.notes = notes
        self.createdAt = Date()
        self.completedAt = nil
    }

    var sourceIcon: String {
        switch sourceModule {
        case "commandCenter": return "bolt.fill"
        case "workSuite": return "building.columns.fill"
        case "familyHQ": return "house.fill"
        case "socialCircle": return "person.2.fill"
        case "explore": return "safari.fill"
        case "balance": return "heart.fill"
        default: return "circle.fill"
        }
    }

    var formattedTimeEstimate: String {
        if timeEstimateMinutes < 60 {
            return "\(timeEstimateMinutes)m"
        } else {
            let hours = timeEstimateMinutes / 60
            let mins = timeEstimateMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}
