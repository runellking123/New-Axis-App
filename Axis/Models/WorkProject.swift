import Foundation
import SwiftData

@Model
final class WorkProject {
    var uuid: UUID
    var title: String
    var workspace: String // "wiley" or "consulting"
    var status: String // "active", "completed", "onHold"
    var priority: String // "high", "medium", "low"
    var notes: String
    var dueDate: Date?
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date
    var estimatedPomodoros: Int?

    init(
        title: String,
        workspace: String = "wiley",
        status: String = "active",
        priority: String = "medium",
        notes: String = "",
        dueDate: Date? = nil,
        sortOrder: Int = 0,
        estimatedPomodoros: Int = 0
    ) {
        self.uuid = UUID()
        self.title = title
        self.workspace = workspace
        self.status = status
        self.priority = priority
        self.notes = notes
        self.dueDate = dueDate
        self.completedAt = nil
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.estimatedPomodoros = estimatedPomodoros
    }

    var priorityColor: String {
        switch priority {
        case "high": return "red"
        case "medium": return "orange"
        case "low": return "green"
        default: return "gray"
        }
    }

    var statusLabel: String {
        switch status {
        case "active": return "Active"
        case "completed": return "Done"
        case "onHold": return "On Hold"
        default: return status
        }
    }

    var workspaceIcon: String {
        workspace == "wiley" ? "building.columns.fill" : "briefcase.fill"
    }

    var workspaceLabel: String {
        workspace == "wiley" ? "Wiley University" : "Consulting"
    }
}
