import Foundation

/// Computes trend analytics by aggregating data across all modules.
final class TrendService: @unchecked Sendable {
    static let shared = TrendService()
    private init() {}

    struct TrendData: Equatable {
        var current: TrendPeriod
        var previous: TrendPeriod
        var dailyFocusMinutes: [Double] // one per day in window
        var dailyMoodScores: [Double]
        var dailyInteractions: [Double]
        var dailyHabitCompletions: [Double]
        var dailyPrioritiesCompleted: [Double]
        var insights: [Insight]
    }

    struct TrendPeriod: Equatable {
        var focusMinutes: Int = 0
        var focusSessions: Int = 0
        var pomodorosCompleted: Int = 0
        var prioritiesCompleted: Int = 0
        var prioritiesCreated: Int = 0
        var interactionsLogged: Int = 0
        var uniqueContactsReached: Int = 0
        var averageMoodScore: Double = 0
        var averageEnergyLevel: Double = 0
        var moodEntryCount: Int = 0
        var habitCompletions: Int = 0
        var placesVisited: Int = 0
        var dadWinsCount: Int = 0
        var bestHabitStreak: Int = 0
    }

    struct Insight: Equatable, Identifiable {
        let id = UUID()
        var icon: String
        var message: String
        var category: String // "productivity", "social", "wellness", "habits"
    }

    // MARK: - Compute Trends

    func computeTrends(windowDays: Int) -> TrendData {
        let persistence = PersistenceService.shared
        let calendar = Calendar.current
        let now = Date()
        let currentStart = calendar.date(byAdding: .day, value: -windowDays, to: now)!
        let previousStart = calendar.date(byAdding: .day, value: -windowDays, to: currentStart)!

        // Fetch all data once
        let allSessions = persistence.fetchFocusSessions()
        let allPriorities = persistence.fetchPriorityItems()
        let allInteractions = persistence.fetchAllInteractions()
        let allContacts = persistence.fetchContacts()
        let allPlaces = persistence.fetchSavedPlaces()
        let allDadWins = persistence.fetchDadWins()

        // Current period
        let current = aggregatePeriod(
            start: currentStart, end: now,
            sessions: allSessions, priorities: allPriorities,
            interactions: allInteractions, contacts: allContacts,
            places: allPlaces, dadWins: allDadWins
        )

        // Previous period (for comparison)
        let previous = aggregatePeriod(
            start: previousStart, end: currentStart,
            sessions: allSessions, priorities: allPriorities,
            interactions: allInteractions, contacts: allContacts,
            places: allPlaces, dadWins: allDadWins
        )

        // Daily breakdowns for charts
        let dailyFocus = dailyValues(windowDays: windowDays, from: now) { dayStart, dayEnd in
            Double(allSessions.filter { $0.completedAt >= dayStart && $0.completedAt < dayEnd && $0.sessionType == "work" }
                .reduce(0) { $0 + $1.durationMinutes })
        }

        let dailyInteractions = dailyValues(windowDays: windowDays, from: now) { dayStart, dayEnd in
            Double(allInteractions.filter { $0.date >= dayStart && $0.date < dayEnd }.count)
        }

        let dailyPriorities = dailyValues(windowDays: windowDays, from: now) { dayStart, dayEnd in
            Double(allPriorities.filter { $0.isCompleted && ($0.completedAt ?? .distantPast) >= dayStart && ($0.completedAt ?? .distantPast) < dayEnd }.count)
        }

        // Mood is sparse — fill 0 for days without entries
        let dailyMood = dailyValues(windowDays: windowDays, from: now) { _, _ in
            // Placeholder — mood entries aren't fetched generically yet
            0.0
        }

        let dailyHabits = dailyValues(windowDays: windowDays, from: now) { _, _ in
            0.0
        }

        // Generate insights
        let insights = generateInsights(current: current, previous: previous, windowDays: windowDays)

        return TrendData(
            current: current,
            previous: previous,
            dailyFocusMinutes: dailyFocus,
            dailyMoodScores: dailyMood,
            dailyInteractions: dailyInteractions,
            dailyHabitCompletions: dailyHabits,
            dailyPrioritiesCompleted: dailyPriorities,
            insights: insights
        )
    }

    // MARK: - Period Aggregation

    private func aggregatePeriod(
        start: Date, end: Date,
        sessions: [FocusSession], priorities: [PriorityItem],
        interactions: [Interaction], contacts: [Contact],
        places: [SavedPlace], dadWins: [DadWin]
    ) -> TrendPeriod {
        let periodSessions = sessions.filter { $0.completedAt >= start && $0.completedAt < end }
        let workSessions = periodSessions.filter { $0.sessionType == "work" }

        let periodPriorities = priorities.filter { $0.createdAt >= start && $0.createdAt < end }
        let completedPriorities = periodPriorities.filter(\.isCompleted)

        let periodInteractions = interactions.filter { $0.date >= start && $0.date < end }
        let uniqueContacts = Set(periodInteractions.map(\.contactId))

        let periodPlaces = places.filter { $0.isVisited && $0.createdAt >= start && $0.createdAt < end }
        let periodWins = dadWins.filter { $0.date >= start && $0.date < end }

        // Find best habit streak from contacts (approximation from interaction patterns)
        let contactsWithRecent = contacts.filter { ($0.lastContacted ?? .distantPast) >= start }

        return TrendPeriod(
            focusMinutes: workSessions.reduce(0) { $0 + $1.durationMinutes },
            focusSessions: workSessions.count,
            pomodorosCompleted: workSessions.reduce(0) { $0 + $1.completedPomodoros },
            prioritiesCompleted: completedPriorities.count,
            prioritiesCreated: periodPriorities.count,
            interactionsLogged: periodInteractions.count,
            uniqueContactsReached: uniqueContacts.count,
            averageMoodScore: 0, // populated when mood entries are fully integrated
            averageEnergyLevel: 0,
            moodEntryCount: 0,
            habitCompletions: 0,
            placesVisited: periodPlaces.count,
            dadWinsCount: periodWins.count,
            bestHabitStreak: 0
        )
    }

    // MARK: - Daily Values Helper

    private func dailyValues(windowDays: Int, from now: Date, compute: (Date, Date) -> Double) -> [Double] {
        let calendar = Calendar.current
        var values: [Double] = []
        for dayOffset in stride(from: windowDays - 1, through: 0, by: -1) {
            let dayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now)!)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            values.append(compute(dayStart, dayEnd))
        }
        return values
    }

    // MARK: - Insights Generation

    private func generateInsights(current: TrendPeriod, previous: TrendPeriod, windowDays: Int) -> [Insight] {
        var insights: [Insight] = []

        // Focus insights
        if current.focusMinutes > 0 {
            let focusChange = percentChange(current: Double(current.focusMinutes), previous: Double(previous.focusMinutes))
            if focusChange > 10 {
                insights.append(Insight(icon: "flame.fill", message: "Focus time up \(Int(focusChange))% — you're in the zone.", category: "productivity"))
            } else if focusChange < -10 {
                insights.append(Insight(icon: "tortoise.fill", message: "Focus time dipped \(Int(abs(focusChange)))%. Consider blocking distractions.", category: "productivity"))
            }
        }

        // Priority completion rate
        if current.prioritiesCreated >= 3 {
            let rate = Double(current.prioritiesCompleted) / Double(current.prioritiesCreated) * 100
            if rate >= 80 {
                insights.append(Insight(icon: "star.fill", message: "Crushing it — \(Int(rate))% priority completion rate.", category: "productivity"))
            } else if rate < 50 {
                insights.append(Insight(icon: "exclamationmark.triangle", message: "Only \(Int(rate))% of priorities completed. Try fewer, higher-impact items.", category: "productivity"))
            }
        }

        // Social insights
        if current.uniqueContactsReached > previous.uniqueContactsReached && current.uniqueContactsReached >= 3 {
            insights.append(Insight(icon: "person.2.fill", message: "Social engagement up — connected with \(current.uniqueContactsReached) people.", category: "social"))
        } else if current.interactionsLogged == 0 && windowDays >= 7 {
            insights.append(Insight(icon: "phone.arrow.up.right", message: "No interactions logged in \(windowDays) days. Reach out to someone.", category: "social"))
        }

        // Explore insights
        if current.placesVisited > 0 {
            insights.append(Insight(icon: "mappin.and.ellipse", message: "Explored \(current.placesVisited) new place\(current.placesVisited == 1 ? "" : "s") this period.", category: "wellness"))
        }

        // Dad wins
        if current.dadWinsCount > previous.dadWinsCount {
            insights.append(Insight(icon: "hands.clap.fill", message: "\(current.dadWinsCount) dad wins — keep celebrating the moments.", category: "wellness"))
        }

        // Pomodoro streaks
        if current.pomodorosCompleted >= 10 {
            let avgPerDay = Double(current.pomodorosCompleted) / Double(windowDays)
            insights.append(Insight(icon: "timer", message: String(format: "Averaging %.1f pomodoros/day across %d sessions.", avgPerDay, current.focusSessions), category: "productivity"))
        }

        // Ensure at least one insight
        if insights.isEmpty {
            insights.append(Insight(icon: "lightbulb.fill", message: "Keep using AXIS and trends will appear as data grows.", category: "productivity"))
        }

        return Array(insights.prefix(5))
    }

    private func percentChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return ((current - previous) / previous) * 100
    }
}
