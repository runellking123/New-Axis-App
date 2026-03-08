import Foundation
import SwiftData

@Model
final class RoutineCompletion {
    var uuid: UUID
    var routineId: UUID
    var date: Date
    var completedStepIds: [UUID]
    var createdAt: Date

    init(
        routineId: UUID,
        date: Date = Date(),
        completedStepIds: [UUID] = []
    ) {
        self.uuid = UUID()
        self.routineId = routineId
        self.date = date
        self.completedStepIds = completedStepIds
        self.createdAt = Date()
    }
}
