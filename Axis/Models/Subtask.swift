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
