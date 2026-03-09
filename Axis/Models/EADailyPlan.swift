import Foundation
import SwiftData

@Model
final class EADailyPlan {
    var uuid: UUID
    var date: Date
    var aiSummary: String?
    var generatedAt: Date

    init(
        date: Date = Date(),
        aiSummary: String? = nil
    ) {
        self.uuid = UUID()
        self.date = date
        self.aiSummary = aiSummary
        self.generatedAt = Date()
    }

    var isStale: Bool {
        abs(generatedAt.timeIntervalSinceNow) > 3 * 3600 // >3 hours old
    }
}
