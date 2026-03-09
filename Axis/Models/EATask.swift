import Foundation
import SwiftData

@Model
final class EATask {
    var uuid: UUID
    var title: String
    var taskDescription: String?
    var deadline: Date?
    var priority: String // critical, high, medium, low
    var energyLevel: String // deepWork, lightWork
    var status: String // inbox, scheduled, inProgress, completed, cancelled
    var category: String // university, consulting, personal
    var estimatedMinutes: Int?
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var projectId: UUID?
    var isRecurring: Bool?
    var recurrenceRule: String?
    var tags: [String]?
    var aiReasoning: String?
    var createdAt: Date

    init(
        title: String,
        taskDescription: String? = nil,
        deadline: Date? = nil,
        priority: String = "medium",
        energyLevel: String = "lightWork",
        status: String = "inbox",
        category: String = "personal",
        estimatedMinutes: Int? = nil,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        projectId: UUID? = nil,
        isRecurring: Bool? = nil,
        recurrenceRule: String? = nil,
        tags: [String]? = nil,
        aiReasoning: String? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.deadline = deadline
        self.priority = priority
        self.energyLevel = energyLevel
        self.status = status
        self.category = category
        self.estimatedMinutes = estimatedMinutes
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.projectId = projectId
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.tags = tags
        self.aiReasoning = aiReasoning
        self.createdAt = Date()
    }

    var isAtRisk: Bool {
        guard let deadline else { return false }
        let hoursUntil = deadline.timeIntervalSince(Date()) / 3600
        return hoursUntil < 72 && scheduledStart == nil && status != "completed" && status != "cancelled"
    }

    var priorityRank: Int {
        switch priority {
        case "critical": return 0
        case "high": return 1
        case "medium": return 2
        case "low": return 3
        default: return 4
        }
    }
}
