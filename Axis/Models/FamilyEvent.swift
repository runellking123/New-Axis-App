import Foundation
import SwiftData

@Model
final class FamilyEvent {
    var uuid: UUID
    var title: String
    var category: String // "activity", "appointment", "school", "meal", "outing"
    var date: Date
    var isAllDay: Bool
    var notes: String
    var isCompleted: Bool
    var assignedTo: String // "runell", "morgan", "family"
    var createdAt: Date

    init(
        title: String,
        category: String = "activity",
        date: Date = Date(),
        isAllDay: Bool = false,
        notes: String = "",
        isCompleted: Bool = false,
        assignedTo: String = "family"
    ) {
        self.uuid = UUID()
        self.title = title
        self.category = category
        self.date = date
        self.isAllDay = isAllDay
        self.notes = notes
        self.isCompleted = isCompleted
        self.assignedTo = assignedTo
        self.createdAt = Date()
    }

    var categoryIcon: String {
        switch category {
        case "activity": return "figure.run"
        case "appointment": return "cross.case.fill"
        case "school": return "graduationcap.fill"
        case "meal": return "fork.knife"
        case "outing": return "car.fill"
        default: return "calendar"
        }
    }

    var assignedIcon: String {
        switch assignedTo {
        case "runell": return "person.fill"
        case "morgan": return "person.fill"
        case "family": return "figure.and.child.holdinghands"
        default: return "person.fill"
        }
    }
}
