import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var wakeTime: Date
    var workStartTime: Date
    var workEndTime: Date
    var preferredContextMode: String
    var onboardingComplete: Bool
    var createdAt: Date

    init(
        name: String = "Runell",
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 30)) ?? Date(),
        workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
        workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date(),
        preferredContextMode: String = "work",
        onboardingComplete: Bool = false
    ) {
        self.name = name
        self.wakeTime = wakeTime
        self.workStartTime = workStartTime
        self.workEndTime = workEndTime
        self.preferredContextMode = preferredContextMode
        self.onboardingComplete = onboardingComplete
        self.createdAt = Date()
    }
}
