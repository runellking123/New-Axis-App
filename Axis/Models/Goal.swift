import Foundation
import SwiftData

@Model
final class Goal {
    var uuid: UUID
    var title: String
    var category: String // "family", "career", "health", "personal", "financial"
    var targetDate: Date?
    var notes: String
    var createdAt: Date
    var completedAt: Date?

    @Relationship(deleteRule: .cascade) var milestones: [Milestone]

    init(
        title: String,
        category: String = "personal",
        targetDate: Date? = nil,
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.title = title
        self.category = category
        self.targetDate = targetDate
        self.notes = notes
        self.createdAt = Date()
        self.completedAt = nil
        self.milestones = []
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var progress: Double {
        guard !milestones.isEmpty else { return 0 }
        let completed = milestones.filter(\.isCompleted).count
        return Double(completed) / Double(milestones.count)
    }

    var completedMilestoneCount: Int {
        milestones.filter(\.isCompleted).count
    }

    var categoryIcon: String {
        switch category {
        case "family": return "house.fill"
        case "career": return "briefcase.fill"
        case "health": return "heart.fill"
        case "personal": return "person.fill"
        case "financial": return "dollarsign.circle.fill"
        default: return "target"
        }
    }

    var categoryColor: String {
        switch category {
        case "family": return "blue"
        case "career": return "orange"
        case "health": return "green"
        case "personal": return "purple"
        case "financial": return "yellow"
        default: return "gray"
        }
    }
}
