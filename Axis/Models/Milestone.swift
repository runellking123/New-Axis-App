import Foundation
import SwiftData

@Model
final class Milestone {
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var sortOrder: Int = 0
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
