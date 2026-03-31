import Foundation
import SwiftData

@Model
final class EATimeBlock {
    var uuid: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date = Date()
    var blockType: String = "" // task, meeting, focusBlock, break
    var taskId: UUID?
    var eventId: String?
    var title: String?
    var aiReasoning: String?
    var planId: UUID = UUID()

    init(
        startTime: Date,
        endTime: Date,
        blockType: String = "task",
        taskId: UUID? = nil,
        eventId: String? = nil,
        title: String? = nil,
        aiReasoning: String? = nil,
        planId: UUID
    ) {
        self.uuid = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.blockType = blockType
        self.taskId = taskId
        self.eventId = eventId
        self.title = title
        self.aiReasoning = aiReasoning
        self.planId = planId
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var blockColor: String {
        switch blockType {
        case "task": return "axisGold"
        case "meeting": return "purple"
        case "focusBlock": return "blue"
        case "break": return "green"
        default: return "gray"
        }
    }
}
