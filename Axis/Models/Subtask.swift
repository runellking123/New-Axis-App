import Foundation
import SwiftData

@Model
final class Subtask {
    var uuid: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var projectId: UUID
    var createdAt: Date

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
}
