import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var uuid: UUID = UUID()
    var habitId: UUID = UUID()
    var date: Date = Date()
    var createdAt: Date = Date()

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
