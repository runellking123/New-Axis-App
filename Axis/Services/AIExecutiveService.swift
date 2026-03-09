import Foundation
import NaturalLanguage

@Observable
final class AIExecutiveService {
    static let shared = AIExecutiveService()

    private(set) var isProcessing = false
    private var lastCallTime: Date?
    private let debounceInterval: TimeInterval = 0.8

    private init() {}

    // MARK: - Parsed Task

    struct ParsedTask: Codable, Equatable {
        var title: String
        var deadline: Date?
        var priority: String // critical, high, medium, low
        var estimatedMinutes: Int?
        var energyLevel: String // deepWork, lightWork
        var tags: [String]?
        var category: String // university, consulting, personal
    }

    // MARK: - Scaffolded Project

    struct ScaffoldedProject: Codable, Equatable {
        var title: String
        var description: String?
        var subtasks: [ScaffoldedTask]
        var milestones: [ScaffoldedMilestone]
        var estimatedDays: Int?
        var category: String
    }

    struct ScaffoldedTask: Codable, Equatable {
        var title: String
        var priority: String
        var estimatedMinutes: Int?
        var order: Int
    }

    struct ScaffoldedMilestone: Codable, Equatable {
        var title: String
        var relativeDayOffset: Int
        var order: Int
    }

    // MARK: - Daily Plan

    struct DailyPlanResult: Codable, Equatable {
        var summary: String
        var timeBlocks: [PlannedBlock]
    }

    struct PlannedBlock: Codable, Equatable {
        var title: String
        var startTime: String // "HH:mm"
        var endTime: String   // "HH:mm"
        var blockType: String // task, meeting, focusBlock, break
        var taskId: String?
        var eventId: String?
        var reasoning: String?
    }

    // MARK: - Next Best Action

    struct NextBestAction: Equatable {
        var taskTitle: String
        var taskId: UUID?
        var reasoning: String
    }

    // MARK: - Capture Classification

    struct CaptureClassification: Equatable {
        var type: String // task, event, note
        var confidence: Double
        var parsedTitle: String?
        var parsedDeadline: Date?
        var parsedPriority: String?
    }

    // MARK: - On-Device Task Parsing (NLP)

    func parseTask(input: String) -> ParsedTask {
        let lowered = input.lowercased()

        // Priority detection
        let priority: String
        if lowered.contains("urgent") || lowered.contains("asap") || lowered.contains("critical") {
            priority = "critical"
        } else if lowered.contains("important") || lowered.contains("high priority") {
            priority = "high"
        } else if lowered.contains("low priority") || lowered.contains("whenever") || lowered.contains("eventually") {
            priority = "low"
        } else {
            priority = "medium"
        }

        // Category detection
        let category: String
        let workKeywords = ["ipeds", "sacscoc", "enrollment", "wiley", "databricks", "dashboard", "report",
                           "meeting", "presentation", "committee", "faculty", "dean", "provost", "budget"]
        let consultingKeywords = ["consulting", "client", "invoice", "contract", "proposal", "deliverable"]

        if workKeywords.contains(where: { lowered.contains($0) }) {
            category = "university"
        } else if consultingKeywords.contains(where: { lowered.contains($0) }) {
            category = "consulting"
        } else {
            category = "personal"
        }

        // Energy detection
        let energyLevel: String
        let deepWorkKeywords = ["write", "code", "analyze", "research", "design", "build", "create", "develop"]
        if deepWorkKeywords.contains(where: { lowered.contains($0) }) {
            energyLevel = "deepWork"
        } else {
            energyLevel = "lightWork"
        }

        // Duration detection
        let estimatedMinutes: Int?
        if let match = lowered.range(of: #"(\d+)\s*(min|minute)"#, options: .regularExpression) {
            let numStr = lowered[match].filter(\.isNumber)
            estimatedMinutes = Int(numStr)
        } else if let match = lowered.range(of: #"(\d+)\s*(hr|hour)"#, options: .regularExpression) {
            let numStr = lowered[match].filter(\.isNumber)
            estimatedMinutes = (Int(numStr) ?? 1) * 60
        } else {
            estimatedMinutes = nil
        }

        // Deadline detection
        let deadline = extractDeadline(from: lowered)

        // Clean title — remove detected metadata
        var title = input
            .replacingOccurrences(of: "urgent", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "asap", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "high priority", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "low priority", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = input }

        return ParsedTask(
            title: title,
            deadline: deadline,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            energyLevel: energyLevel,
            tags: nil,
            category: category
        )
    }

    // MARK: - On-Device Capture Classification

    func classifyCapture(input: String) -> CaptureClassification {
        let lowered = input.lowercased()

        // Event keywords
        let eventKeywords = ["meeting", "appointment", "call at", "call with", "lunch with",
                            "dinner at", "event", "at \\d", "on \\w+day"]
        let eventScore = eventKeywords.filter { lowered.range(of: $0, options: .regularExpression) != nil }.count

        // Task keywords
        let taskKeywords = ["todo", "to do", "need to", "finish", "complete", "submit", "send",
                           "buy", "get", "make", "prepare", "write", "review", "fix", "update"]
        let taskScore = taskKeywords.filter { lowered.contains($0) }.count

        // Note keywords
        let noteKeywords = ["remember", "note", "idea", "thought", "don't forget"]
        let noteScore = noteKeywords.filter { lowered.contains($0) }.count

        let type: String
        let confidence: Double
        let maxScore = max(eventScore, taskScore, noteScore)

        if maxScore == 0 {
            type = "task"
            confidence = 0.5
        } else if eventScore >= taskScore && eventScore >= noteScore {
            type = "event"
            confidence = min(0.95, 0.6 + Double(eventScore) * 0.15)
        } else if taskScore >= noteScore {
            type = "task"
            confidence = min(0.95, 0.6 + Double(taskScore) * 0.1)
        } else {
            type = "note"
            confidence = min(0.95, 0.6 + Double(noteScore) * 0.15)
        }

        return CaptureClassification(
            type: type,
            confidence: confidence,
            parsedTitle: input.trimmingCharacters(in: .whitespacesAndNewlines),
            parsedDeadline: extractDeadline(from: lowered),
            parsedPriority: nil
        )
    }

    // MARK: - On-Device Next Best Action

    func nextBestAction(tasks: [EATask], energyScore: Int) -> NextBestAction? {
        guard !tasks.isEmpty else { return nil }

        let now = Date()
        let activeTasks = tasks.filter { $0.status != "completed" && $0.status != "cancelled" }
        guard !activeTasks.isEmpty else { return nil }

        // Score each task
        var bestTask: EATask?
        var bestScore: Double = -1

        for task in activeTasks {
            var score: Double = 0

            // Urgency: deadline proximity
            if let deadline = task.deadline {
                let hoursUntil = deadline.timeIntervalSince(now) / 3600
                if hoursUntil < 0 { score += 50 } // overdue
                else if hoursUntil < 24 { score += 30 }
                else if hoursUntil < 72 { score += 15 }
            }

            // Priority weight
            switch task.priority {
            case "critical": score += 25
            case "high": score += 15
            case "medium": score += 5
            default: break
            }

            // Energy match
            if energyScore >= 7 && task.energyLevel == "deepWork" {
                score += 10
            } else if energyScore < 5 && task.energyLevel == "lightWork" {
                score += 10
            }

            // Already scheduled = slight boost (it's planned)
            if task.scheduledStart != nil { score += 5 }

            if score > bestScore {
                bestScore = score
                bestTask = task
            }
        }

        guard let recommended = bestTask else { return nil }

        // Generate reasoning
        var reasoning: String
        if let deadline = recommended.deadline {
            let hoursUntil = deadline.timeIntervalSince(now) / 3600
            if hoursUntil < 0 {
                reasoning = "This is overdue — tackle it now."
            } else if hoursUntil < 24 {
                reasoning = "Due in less than 24 hours."
            } else if hoursUntil < 72 {
                reasoning = "Due soon — get ahead of it."
            } else {
                reasoning = "High priority item worth starting now."
            }
        } else if recommended.priority == "critical" {
            reasoning = "Critical priority — needs attention."
        } else if energyScore >= 7 && recommended.energyLevel == "deepWork" {
            reasoning = "Your energy is high — ideal for deep work."
        } else {
            reasoning = "Good match for your current energy level."
        }

        return NextBestAction(
            taskTitle: recommended.title,
            taskId: recommended.uuid,
            reasoning: reasoning
        )
    }

    // MARK: - On-Device Daily Plan Generation

    func generateDailyPlan(
        tasks: [EATask],
        events: [CalendarService.CalendarEvent],
        energyScore: Int,
        workStartHour: Int = 8,
        workEndHour: Int = 17
    ) -> DailyPlanResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var blocks: [PlannedBlock] = []

        // Convert events to blocks first (immovable)
        for event in events where !event.isAllDay {
            blocks.append(PlannedBlock(
                title: event.title,
                startTime: formatTime(event.startDate),
                endTime: formatTime(event.endDate),
                blockType: "meeting",
                taskId: nil,
                eventId: event.id,
                reasoning: nil
            ))
        }

        // Sort tasks by priority then deadline
        let schedulableTasks = tasks
            .filter { $0.status != "completed" && $0.status != "cancelled" }
            .sorted { a, b in
                if a.priorityRank != b.priorityRank { return a.priorityRank < b.priorityRank }
                let aDeadline = a.deadline ?? .distantFuture
                let bDeadline = b.deadline ?? .distantFuture
                return aDeadline < bDeadline
            }

        // Find available slots and assign tasks
        // Morning = deep work (before noon), Afternoon = meetings/light work
        let deepWorkTasks = schedulableTasks.filter { $0.energyLevel == "deepWork" }
        let lightTasks = schedulableTasks.filter { $0.energyLevel != "deepWork" }

        var currentMorningTime = calendar.date(bySettingHour: workStartHour, minute: 0, second: 0, of: today) ?? today
        let noonTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        var currentAfternoonTime = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today
        let endTime = calendar.date(bySettingHour: workEndHour, minute: 0, second: 0, of: today) ?? today

        // Schedule deep work in the morning
        for task in deepWorkTasks.prefix(3) {
            let duration = TimeInterval((task.estimatedMinutes ?? 30) * 60)
            let blockEnd = currentMorningTime.addingTimeInterval(duration)
            guard blockEnd <= noonTime else { break }

            // Check for conflicts with events
            let hasConflict = blocks.contains { existingBlock in
                guard existingBlock.blockType == "meeting" else { return false }
                let eStart = parseTime(existingBlock.startTime, on: today)
                let eEnd = parseTime(existingBlock.endTime, on: today)
                return currentMorningTime < eEnd && blockEnd > eStart
            }

            if !hasConflict {
                blocks.append(PlannedBlock(
                    title: task.title,
                    startTime: formatTime(currentMorningTime),
                    endTime: formatTime(blockEnd),
                    blockType: "focusBlock",
                    taskId: task.uuid.uuidString,
                    eventId: nil,
                    reasoning: "Deep work scheduled in morning for peak focus."
                ))
                currentMorningTime = blockEnd.addingTimeInterval(5 * 60) // 5 min buffer
            }
        }

        // Schedule light tasks in the afternoon
        for task in lightTasks.prefix(4) {
            let duration = TimeInterval((task.estimatedMinutes ?? 25) * 60)
            let blockEnd = currentAfternoonTime.addingTimeInterval(duration)
            guard blockEnd <= endTime else { break }

            let hasConflict = blocks.contains { existingBlock in
                guard existingBlock.blockType == "meeting" else { return false }
                let eStart = parseTime(existingBlock.startTime, on: today)
                let eEnd = parseTime(existingBlock.endTime, on: today)
                return currentAfternoonTime < eEnd && blockEnd > eStart
            }

            if !hasConflict {
                blocks.append(PlannedBlock(
                    title: task.title,
                    startTime: formatTime(currentAfternoonTime),
                    endTime: formatTime(blockEnd),
                    blockType: "task",
                    taskId: task.uuid.uuidString,
                    eventId: nil,
                    reasoning: "Light task scheduled for afternoon."
                ))
                currentAfternoonTime = blockEnd.addingTimeInterval(5 * 60)
            }
        }

        // Sort all blocks by time
        blocks.sort { $0.startTime < $1.startTime }

        // Generate summary
        let taskCount = blocks.filter { $0.blockType != "meeting" }.count
        let meetingCount = blocks.filter { $0.blockType == "meeting" }.count
        let summary = "\(taskCount) task\(taskCount == 1 ? "" : "s") and \(meetingCount) meeting\(meetingCount == 1 ? "" : "s") planned. Morning focused on deep work."

        return DailyPlanResult(summary: summary, timeBlocks: blocks)
    }

    // MARK: - Replan

    func replanDay(
        currentPlan: DailyPlanResult,
        tasks: [EATask],
        events: [CalendarService.CalendarEvent],
        energyScore: Int
    ) -> DailyPlanResult {
        // Regenerate with current data
        return generateDailyPlan(tasks: tasks, events: events, energyScore: energyScore)
    }

    // MARK: - Project Scaffolding (On-Device)

    func scaffoldProject(description: String) -> ScaffoldedProject {
        let lowered = description.lowercased()

        // Category detection
        let category: String
        let workKeywords = ["report", "ipeds", "enrollment", "accreditation", "dashboard", "data"]
        let consultingKeywords = ["client", "consulting", "deliverable", "proposal"]
        if workKeywords.contains(where: { lowered.contains($0) }) {
            category = "university"
        } else if consultingKeywords.contains(where: { lowered.contains($0) }) {
            category = "consulting"
        } else {
            category = "personal"
        }

        // Generate subtasks based on project type
        var subtasks: [ScaffoldedTask] = []
        var milestones: [ScaffoldedMilestone] = []

        if lowered.contains("report") || lowered.contains("analysis") {
            subtasks = [
                ScaffoldedTask(title: "Gather data sources", priority: "high", estimatedMinutes: 60, order: 0),
                ScaffoldedTask(title: "Clean and validate data", priority: "high", estimatedMinutes: 90, order: 1),
                ScaffoldedTask(title: "Build analysis framework", priority: "medium", estimatedMinutes: 120, order: 2),
                ScaffoldedTask(title: "Generate visualizations", priority: "medium", estimatedMinutes: 60, order: 3),
                ScaffoldedTask(title: "Write narrative summary", priority: "medium", estimatedMinutes: 90, order: 4),
                ScaffoldedTask(title: "Review and finalize", priority: "high", estimatedMinutes: 45, order: 5),
            ]
            milestones = [
                ScaffoldedMilestone(title: "Data collection complete", relativeDayOffset: 3, order: 0),
                ScaffoldedMilestone(title: "Analysis draft ready", relativeDayOffset: 7, order: 1),
                ScaffoldedMilestone(title: "Final submission", relativeDayOffset: 10, order: 2),
            ]
        } else if lowered.contains("presentation") || lowered.contains("deck") {
            subtasks = [
                ScaffoldedTask(title: "Define audience and objectives", priority: "high", estimatedMinutes: 30, order: 0),
                ScaffoldedTask(title: "Create outline", priority: "high", estimatedMinutes: 45, order: 1),
                ScaffoldedTask(title: "Design slides", priority: "medium", estimatedMinutes: 120, order: 2),
                ScaffoldedTask(title: "Add supporting data", priority: "medium", estimatedMinutes: 60, order: 3),
                ScaffoldedTask(title: "Practice run-through", priority: "high", estimatedMinutes: 30, order: 4),
            ]
            milestones = [
                ScaffoldedMilestone(title: "Outline approved", relativeDayOffset: 2, order: 0),
                ScaffoldedMilestone(title: "Slides complete", relativeDayOffset: 5, order: 1),
                ScaffoldedMilestone(title: "Presentation day", relativeDayOffset: 7, order: 2),
            ]
        } else {
            // Generic project
            subtasks = [
                ScaffoldedTask(title: "Define scope and requirements", priority: "high", estimatedMinutes: 45, order: 0),
                ScaffoldedTask(title: "Research and planning", priority: "medium", estimatedMinutes: 60, order: 1),
                ScaffoldedTask(title: "Execute main work", priority: "high", estimatedMinutes: 120, order: 2),
                ScaffoldedTask(title: "Review and iterate", priority: "medium", estimatedMinutes: 60, order: 3),
                ScaffoldedTask(title: "Finalize and deliver", priority: "high", estimatedMinutes: 30, order: 4),
            ]
            milestones = [
                ScaffoldedMilestone(title: "Planning complete", relativeDayOffset: 3, order: 0),
                ScaffoldedMilestone(title: "First draft ready", relativeDayOffset: 7, order: 1),
                ScaffoldedMilestone(title: "Project complete", relativeDayOffset: 14, order: 2),
            ]
        }

        return ScaffoldedProject(
            title: description.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            subtasks: subtasks,
            milestones: milestones,
            estimatedDays: milestones.last?.relativeDayOffset,
            category: category
        )
    }

    // MARK: - Helpers

    private func extractDeadline(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        if text.contains("today") {
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)
        } else if text.contains("tomorrow") {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: tomorrow)
        } else if text.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if text.contains("this friday") || text.contains("by friday") {
            return nextWeekday(.friday, from: now)
        } else if text.contains("this monday") || text.contains("by monday") {
            return nextWeekday(.monday, from: now)
        }
        return nil
    }

    private func nextWeekday(_ weekday: Calendar.Weekday, from date: Date) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday.rawValue
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseTime(_ timeStr: String, on date: Date) -> Date {
        let components = timeStr.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return date }
        return Calendar.current.date(bySettingHour: components[0], minute: components[1], second: 0, of: date) ?? date
    }
}

// Extension for Calendar.Weekday (if not available)
extension Calendar {
    enum Weekday: Int {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }
}
