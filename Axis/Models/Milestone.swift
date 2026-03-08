import Foundation
import SwiftData

@Model
final class Milestone {
    var uuid: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var goal: Goal?

    init(
        title: String,
        sortOrder: Int = 0
    ) {
        self.uuid = UUID()
        self.title = title
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = sortOrder
    }
}
