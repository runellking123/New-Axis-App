import Foundation
import NaturalLanguage

@Observable
final class AIService {
    static let shared = AIService()

    private init() {}

    // MARK: - On-Device Classification

    /// Classifies a captured note into the appropriate module using NLP
    func classifyNote(_ text: String) -> String {
        let lowered = text.lowercased()

        // Work keywords
        let workKeywords = ["meeting", "deadline", "report", "ipeds", "sacscoc", "cbm", "enrollment",
                           "wiley", "consulting", "kanisha", "shneka", "databricks", "dashboard",
                           "presentation", "budget", "committee", "faculty", "provost", "dean"]

        // Family keywords
        let familyKeywords = ["morgan", "kids", "pickup", "school", "dinner", "grocery", "family",
                             "doctor", "appointment", "soccer", "practice", "birthday", "homework"]

        // Social keywords
        let socialKeywords = ["call", "text", "catch up", "friend", "lunch with", "drinks",
                             "birthday party", "wedding", "reunion", "check in"]

        // Explore keywords
        let exploreKeywords = ["restaurant", "movie", "concert", "trip", "travel", "hotel",
                              "reservation", "event", "ticket", "museum", "park"]

        // Balance keywords
        let balanceKeywords = ["workout", "gym", "sleep", "meditation", "walk", "run",
                              "health", "stress", "relax", "self-care", "therapy"]

        let scores: [(String, Int)] = [
            ("workSuite", workKeywords.filter { lowered.contains($0) }.count),
            ("familyHQ", familyKeywords.filter { lowered.contains($0) }.count),
            ("socialCircle", socialKeywords.filter { lowered.contains($0) }.count),
            ("explore", exploreKeywords.filter { lowered.contains($0) }.count),
            ("balance", balanceKeywords.filter { lowered.contains($0) }.count)
        ]

        return scores.max(by: { $0.1 < $1.1 })?.1 ?? 0 > 0
            ? scores.max(by: { $0.1 < $1.1 })!.0
            : "commandCenter"
    }

    // MARK: - Sentiment Analysis (On-Device)

    func analyzeSentiment(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }

    // MARK: - Weekly Report Generation

    struct WeeklyReport: Equatable {
        var completedPriorities: Int
        var totalPriorities: Int
        var dadWinsCount: Int
        var averageEnergy: Double
        var topMood: String
        var contactsReachedOut: Int
        var placesExplored: Int
        var summary: String
        var highlights: [String]
        var improvementAreas: [String]
    }

    func generateWeeklyReport(days: Int = 7) -> WeeklyReport {
        let persistence = PersistenceService.shared
        let windowDays = max(days, 1)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()

        // Priorities
        let allPriorities = persistence.fetchPriorityItems()
        let recentPriorities = allPriorities.filter { $0.createdAt >= cutoffDate }
        let completedCount = recentPriorities.filter(\.isCompleted).count

        // Dad Wins
        let allWins = persistence.fetchDadWins()
        let recentWins = allWins.filter { $0.date >= cutoffDate }

        // Contacts
        let contacts = persistence.fetchContacts()
        let recentContacts = contacts.filter { ($0.lastContacted ?? .distantPast) >= cutoffDate }

        // Places
        let places = persistence.fetchSavedPlaces()
        let recentVisited = places.filter { $0.isVisited && $0.createdAt >= cutoffDate }

        // Determine top mood from dad wins
        let moodCounts = Dictionary(grouping: recentWins, by: \.mood).mapValues(\.count)
        let topMood = moodCounts.max(by: { $0.value < $1.value })?.key ?? "proud"

        // Highlights
        var highlights: [String] = []
        if completedCount > 0 {
            highlights.append("Crushed \(completedCount) priorities in the last \(windowDays) days")
        }
        if recentWins.count > 0 {
            highlights.append("Logged \(recentWins.count) dad win\(recentWins.count == 1 ? "" : "s")")
        }
        if recentContacts.count > 0 {
            highlights.append("Connected with \(recentContacts.count) people in \(windowDays) days")
        }
        if recentVisited.count > 0 {
            highlights.append("Explored \(recentVisited.count) new place\(recentVisited.count == 1 ? "" : "s")")
        }
        if highlights.isEmpty {
            highlights.append("Fresh window — time to make it count")
        }

        // Improvement areas
        var improvements: [String] = []
        let completionRate = recentPriorities.isEmpty ? 1.0 : Double(completedCount) / Double(recentPriorities.count)
        if completionRate < 0.7 {
            improvements.append("Try breaking priorities into smaller tasks")
        }
        if recentWins.isEmpty {
            improvements.append("Capture a dad win — even small moments matter")
        }
        if recentContacts.count < 2 {
            improvements.append("Reach out to a friend in the next few days")
        }
        if improvements.isEmpty {
            improvements.append("You're on track — keep the momentum going")
        }

        // Summary
        let summaryParts = [
            "Last \(windowDays) days: \(completedCount)/\(recentPriorities.count) priorities done.",
            recentWins.count > 0 ? "\(recentWins.count) dad wins recorded." : "No dad wins yet.",
            "Feeling mostly \(topMood).",
        ]

        return WeeklyReport(
            completedPriorities: completedCount,
            totalPriorities: recentPriorities.count,
            dadWinsCount: recentWins.count,
            averageEnergy: 7.0,
            topMood: topMood,
            contactsReachedOut: recentContacts.count,
            placesExplored: recentVisited.count,
            summary: summaryParts.joined(separator: " "),
            highlights: highlights,
            improvementAreas: improvements
        )
    }

    // MARK: - Day Brief Generation

    func generateDayBriefSummary(
        events: [CalendarService.CalendarEvent],
        priorities: [PriorityItem],
        weather: WeatherService.WeatherData?
    ) -> String {
        var parts: [String] = []

        // Events summary
        let eventCount = events.count
        if eventCount > 0 {
            let firstEvent = events.first!
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            parts.append("You have \(eventCount) event\(eventCount == 1 ? "" : "s") today. First up: \(firstEvent.title) at \(formatter.string(from: firstEvent.startDate)).")
        } else {
            parts.append("No meetings today — clear runway for deep work.")
        }

        // Priority summary
        let openPriorities = priorities.filter { !$0.isCompleted }
        if !openPriorities.isEmpty {
            let totalMinutes = openPriorities.reduce(0) { $0 + $1.timeEstimateMinutes }
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
            parts.append("\(openPriorities.count) priorities queued (~\(timeStr) estimated).")
        }

        // Weather
        if let weather {
            parts.append(weather.actionableNote)
        }

        return parts.joined(separator: " ")
    }
}
