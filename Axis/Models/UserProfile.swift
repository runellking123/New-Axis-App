import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var wakeTime: Date
    var workStartTime: Date
    var workEndTime: Date
    var preferredContextMode: String
    var stepsGoal: Int
    var defaultFocusMinutes: Int
    var notificationsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    var onboardingComplete: Bool
    var createdAt: Date

    init(
        name: String = "Runell",
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 30)) ?? Date(),
        workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
        workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date(),
        preferredContextMode: String = "work",
        stepsGoal: Int = 10000,
        defaultFocusMinutes: Int = 25,
        notificationsEnabled: Bool = true,
        hapticFeedbackEnabled: Bool = true,
        onboardingComplete: Bool = false
    ) {
        self.name = name
        self.wakeTime = wakeTime
        self.workStartTime = workStartTime
        self.workEndTime = workEndTime
        self.preferredContextMode = preferredContextMode
        self.stepsGoal = stepsGoal
        self.defaultFocusMinutes = defaultFocusMinutes
        self.notificationsEnabled = notificationsEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.onboardingComplete = onboardingComplete
        self.createdAt = Date()
    }
}
