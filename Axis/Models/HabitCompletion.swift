import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var uuid: UUID
    var habitId: UUID
    var date: Date
    var createdAt: Date

    init(
        habitId: UUID,
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.habitId = habitId
        self.date = date
        self.createdAt = Date()
    }
}
