import Foundation
import SwiftData

@Model
final class RoutineCompletion {
    var uuid: UUID = UUID()
    var routineId: UUID = UUID()
    var date: Date = Date()
    var completedStepIds: [UUID] = []
    var createdAt: Date = Date()

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
