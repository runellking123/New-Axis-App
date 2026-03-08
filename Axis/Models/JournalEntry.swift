import Foundation
import SwiftData

@Model
final class JournalEntry {
    var uuid: UUID
    var content: String
    var gratitudeItems: [String]
    var mood: String
    var date: Date
    var createdAt: Date

    init(
        content: String = "",
        gratitudeItems: [String] = [],
        mood: String = "",
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.content = content
        self.gratitudeItems = gratitudeItems
        self.mood = mood
        self.date = date
        self.createdAt = Date()
    }
}
