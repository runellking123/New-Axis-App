import Foundation
import SwiftData

@Model
final class Subtask {
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var projectId: UUID = UUID()
    var createdAt: Date = Date()
    // Set when this subtask belongs to an EKReminder rather than a legacy
    // EAProject. Holds the reminder's calendarItemIdentifier.
    var reminderId: String? = nil

    init(
        title: String,
        projectId: UUID,
        sortOrder: Int = 0,
        isCompleted: Bool = false
    ) {
        self.uuid = UUID()
        self.title = title
        self.projectId = projectId
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }

    init(
        title: String,
        reminderId: String,
        sortOrder: Int = 0,
        isCompleted: Bool = false
    ) {
        self.uuid = UUID()
        self.title = title
        self.projectId = UUID()
        self.reminderId = reminderId
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}
