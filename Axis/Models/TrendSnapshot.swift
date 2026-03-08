import Foundation
import SwiftData

@Model
final class TrendSnapshot {
    var uuid: UUID
    var date: Date
    var windowDays: Int // 7, 14, 30, 90

    // Work & Focus
    var focusMinutes: Int
    var focusSessions: Int
    var pomodorosCompleted: Int
    var prioritiesCompleted: Int
    var prioritiesCreated: Int

    // Social
    var interactionsLogged: Int
    var contactsReachedOut: Int

    // Balance & Wellness
    var averageMoodScore: Double // 1-5 mapped from great=5..terrible=1
    var averageEnergyLevel: Double // 1-5
    var moodEntryCount: Int
    var waterOunces: Double

    // Habits
    var habitCompletions: Int
    var habitsDueCount: Int

    // Explore
    var placesVisited: Int

    // Family
    var dadWinsCount: Int

    var createdAt: Date

    init(
        date: Date = Date(),
        windowDays: Int = 7,
        focusMinutes: Int = 0,
        focusSessions: Int = 0,
        pomodorosCompleted: Int = 0,
        prioritiesCompleted: Int = 0,
        prioritiesCreated: Int = 0,
        interactionsLogged: Int = 0,
        contactsReachedOut: Int = 0,
        averageMoodScore: Double = 0,
        averageEnergyLevel: Double = 0,
        moodEntryCount: Int = 0,
        waterOunces: Double = 0,
        habitCompletions: Int = 0,
        habitsDueCount: Int = 0,
        placesVisited: Int = 0,
        dadWinsCount: Int = 0
    ) {
        self.uuid = UUID()
        self.date = date
        self.windowDays = windowDays
        self.focusMinutes = focusMinutes
        self.focusSessions = focusSessions
        self.pomodorosCompleted = pomodorosCompleted
        self.prioritiesCompleted = prioritiesCompleted
        self.prioritiesCreated = prioritiesCreated
        self.interactionsLogged = interactionsLogged
        self.contactsReachedOut = contactsReachedOut
        self.averageMoodScore = averageMoodScore
        self.averageEnergyLevel = averageEnergyLevel
        self.moodEntryCount = moodEntryCount
        self.waterOunces = waterOunces
        self.habitCompletions = habitCompletions
        self.habitsDueCount = habitsDueCount
        self.placesVisited = placesVisited
        self.dadWinsCount = dadWinsCount
        self.createdAt = Date()
    }

    var completionRate: Double {
        guard prioritiesCreated > 0 else { return 0 }
        return Double(prioritiesCompleted) / Double(prioritiesCreated)
    }

    var habitCompletionRate: Double {
        guard habitsDueCount > 0 else { return 0 }
        return Double(habitCompletions) / Double(habitsDueCount)
    }
}
