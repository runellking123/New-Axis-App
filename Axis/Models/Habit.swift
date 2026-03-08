import Foundation
import SwiftData

@Model
final class Habit {
    var uuid: UUID
    var name: String
    var frequency: String // "daily", "weekly"
    var targetDaysPerWeek: Int
    var specificDays: [Int] // 1=Mon through 7=Sun
    var streakCurrent: Int
    var streakBest: Int
    var color: String
    var icon: String
    var createdAt: Date

    init(
        name: String,
        frequency: String = "daily",
        targetDaysPerWeek: Int = 7,
        specificDays: [Int] = [],
        color: String = "blue",
        icon: String = "checkmark.circle"
    ) {
        self.uuid = UUID()
        self.name = name
        self.frequency = frequency
        self.targetDaysPerWeek = targetDaysPerWeek
        self.specificDays = specificDays
        self.streakCurrent = 0
        self.streakBest = 0
        self.color = color
        self.icon = icon
        self.createdAt = Date()
    }

    var isDueToday: Bool {
        if frequency == "daily" {
            return true
        }

        if frequency == "weekly" && specificDays.isEmpty {
            return true
        }

        // Calendar weekday: 1=Sun, 2=Mon ... 7=Sat
        // Convert to 1=Mon through 7=Sun
        let calendarWeekday = Calendar.current.component(.weekday, from: Date())
        let adjustedWeekday = calendarWeekday == 1 ? 7 : calendarWeekday - 1

        return specificDays.contains(adjustedWeekday)
    }
}
