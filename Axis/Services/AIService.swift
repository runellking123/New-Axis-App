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
