import Foundation
import SwiftData

@Model
final class FocusSession {
    var uuid: UUID = UUID()
    var completedAt: Date = Date()
    var durationMinutes: Int = 0
    var projectId: UUID?
    var sessionType: String = "" // "work", "shortBreak", "longBreak"
    var completedPomodoros: Int = 0

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
