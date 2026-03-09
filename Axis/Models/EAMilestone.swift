import Foundation
import SwiftData

@Model
final class EAMilestone {
    var uuid: UUID
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
    var projectId: UUID
    var sortOrder: Int
    var createdAt: Date

    init(
        title: String,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        projectId: UUID,
        sortOrder: Int = 0
    ) {
        self.uuid = UUID()
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.projectId = projectId
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
