import Foundation
import SwiftData

@Model
final class EAInboxItem {
    var uuid: UUID
    var rawInput: String
    var classifiedType: String // task, event, note
    var confidence: Double?
    var parsedData: String? // JSON string of parsed fields
    var isReviewed: Bool
    var createdAt: Date

    init(
        rawInput: String,
        classifiedType: String = "task",
        confidence: Double? = nil,
        parsedData: String? = nil,
        isReviewed: Bool = false
    ) {
        self.uuid = UUID()
        self.rawInput = rawInput
        self.classifiedType = classifiedType
        self.confidence = confidence
        self.parsedData = parsedData
        self.isReviewed = isReviewed
        self.createdAt = Date()
    }
}
