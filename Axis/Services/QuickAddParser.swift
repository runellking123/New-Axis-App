import Foundation

// Parses free-text reminder input ("Call mom tomorrow 5pm p1 every weekday")
// into structured fields the editor would normally collect via picker UI.
//
// Date detection uses NSDataDetector (the same engine Mail/Notes use) so
// phrasings like "tomorrow", "next Friday at 5", "in 3 days", "Mar 14" all
// work without bespoke logic. Priority + recurrence are matched by token
// because NSDataDetector doesn't cover them.
enum QuickAddParser {
    struct Result: Equatable {
        var title: String
        var dueDate: Date?
        var includesTime: Bool
        var priority: Int
        var recurrence: CalendarService.RecurrencePreset
    }

    static func parse(_ raw: String, now: Date = Date()) -> Result {
        var working = raw

        let recurrence = extractRecurrence(from: &working)
        let priority = extractPriority(from: &working)
        let (date, hasTime) = extractDate(from: &working, now: now)

        let title = working
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(
            title: title,
            dueDate: date,
            includesTime: hasTime,
            priority: priority,
            recurrence: recurrence
        )
    }

    // MARK: - Recurrence

    private static let recurrencePatterns: [(pattern: String, preset: CalendarService.RecurrencePreset)] = [
        (#"\bevery\s+weekday\b"#, .weekdays),
        (#"\bevery\s+day\b"#, .daily),
        (#"\bdaily\b"#, .daily),
        (#"\bevery\s+week\b"#, .weekly),
        (#"\bweekly\b"#, .weekly),
        (#"\bevery\s+month\b"#, .monthly),
        (#"\bmonthly\b"#, .monthly),
        (#"\bevery\s+year\b"#, .yearly),
        (#"\byearly\b"#, .yearly),
        (#"\bannually\b"#, .yearly),
    ]

    private static func extractRecurrence(from text: inout String) -> CalendarService.RecurrencePreset {
        for (pattern, preset) in recurrencePatterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                text.removeSubrange(range)
                return preset
            }
        }
        return .none
    }

    // MARK: - Priority

    private static func extractPriority(from text: inout String) -> Int {
        let patterns: [(String, Int)] = [
            (#"(?:^|\s)p1\b"#, 1),
            (#"(?:^|\s)p2\b"#, 5),
            (#"(?:^|\s)p3\b"#, 9),
            (#"(?:^|\s)p4\b"#, 0),
            (#"(?:^|\s)!!!"#, 1),
            (#"(?:^|\s)!!"#, 5),
            (#"(?:^|\s)!\b"#, 9),
        ]
        for (pattern, value) in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                text.removeSubrange(range)
                return value
            }
        }
        return 0
    }

    // MARK: - Date

    private static func extractDate(from text: inout String, now: Date) -> (Date?, Bool) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return (nil, false)
        }
        let nsText = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.first, let matchedDate = match.date else { return (nil, false) }

        // NSDataDetector returns either a full date+time or a date with the
        // current time. A duration > 0 OR an explicit time component means
        // the user typed a time like "5pm". A pure date like "tomorrow"
        // gives match.duration == 0 AND the time matches `now` exactly.
        let hasTime = match.duration > 0 || timeWasExplicit(in: nsText.substring(with: match.range))

        // If the detector returned a past time today (e.g. "5pm" entered at 8pm),
        // bump to tomorrow so the user gets a sensible future due date.
        var finalDate = matchedDate
        if hasTime && finalDate < now,
           let bumped = Calendar.current.date(byAdding: .day, value: 1, to: finalDate) {
            finalDate = bumped
        }

        if let range = Range(match.range, in: text) {
            text.removeSubrange(range)
        }
        return (finalDate, hasTime)
    }

    /// Heuristic: if the matched substring contains a digit + am/pm or a colon,
    /// the user typed an explicit time. NSDataDetector's `duration` is 0 for
    /// "tomorrow 5pm" too, so we can't rely on it alone.
    private static func timeWasExplicit(in fragment: String) -> Bool {
        let lower = fragment.lowercased()
        if lower.contains(":") { return true }
        if lower.range(of: #"\d\s?(am|pm)"#, options: .regularExpression) != nil { return true }
        return false
    }
}
