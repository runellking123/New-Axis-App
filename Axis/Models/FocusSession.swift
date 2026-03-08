import Foundation
import SwiftData

@Model
final class FocusSession {
    var uuid: UUID
    var completedAt: Date
    var durationMinutes: Int
    var projectId: UUID?
    var sessionType: String // "work", "shortBreak", "longBreak"
    var completedPomodoros: Int

    init(
        completedAt: Date = Date(),
        durationMinutes: Int,
        projectId: UUID? = nil,
        sessionType: String = "work",
        completedPomodoros: Int = 1
    ) {
        self.uuid = UUID()
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.projectId = projectId
        self.sessionType = sessionType
        self.completedPomodoros = completedPomodoros
    }
}
