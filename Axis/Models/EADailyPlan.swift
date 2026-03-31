import Foundation
import SwiftData

@Model
final class EADailyPlan {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var aiSummary: String?
    var generatedAt: Date = Date()

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
