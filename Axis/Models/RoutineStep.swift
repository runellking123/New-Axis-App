import Foundation
import SwiftData

@Model
final class RoutineStep {
    var uuid: UUID
    var title: String
    var durationSeconds: Int
    var routineId: UUID
    var sortOrder: Int
    var createdAt: Date

    init(
        title: String = "",
        durationSeconds: Int = 0,
        routineId: UUID,
        sortOrder: Int = 0
    ) {
        self.uuid = UUID()
        self.title = title
        self.durationSeconds = durationSeconds
        self.routineId = routineId
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
