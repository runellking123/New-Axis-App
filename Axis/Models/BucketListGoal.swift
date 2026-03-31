import Foundation
import SwiftData

@Model
final class BucketListGoal {
    var uuid: UUID = UUID()
    var title: String = ""
    var category: String = "" // "food", "travel", "adventure", "culture"
    var targetCount: Int = 0
    var completedCount: Int = 0
    var deadline: Date?
    var createdAt: Date = Date()

    init(
        title: String,
        category: String = "travel",
        targetCount: Int = 1,
        completedCount: Int = 0,
        deadline: Date? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.category = category
        self.targetCount = targetCount
        self.completedCount = completedCount
        self.deadline = deadline
        self.createdAt = Date()
    }

    var progress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(completedCount) / Double(targetCount)
    }

    var isComplete: Bool {
        completedCount >= targetCount
    }
}
