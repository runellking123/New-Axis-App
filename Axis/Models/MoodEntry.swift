import Foundation
import SwiftData

@Model
final class MoodEntry {
    var uuid: UUID
    var mood: String // "great", "good", "okay", "bad", "terrible"
    var energyLevel: Int // 1-5
    var notes: String
    var date: Date
    var createdAt: Date

    init(
        mood: String = "okay",
        energyLevel: Int = 3,
        notes: String = "",
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.mood = mood
        self.energyLevel = energyLevel
        self.notes = notes
        self.date = date
        self.createdAt = Date()
    }

    var moodEmoji: String {
        switch mood {
        case "great": return "😄"
        case "good": return "🙂"
        case "okay": return "😐"
        case "bad": return "😞"
        case "terrible": return "😢"
        default: return "😐"
        }
    }

    var moodColor: String {
        switch mood {
        case "great": return "green"
        case "good": return "mint"
        case "okay": return "yellow"
        case "bad": return "orange"
        case "terrible": return "red"
        default: return "gray"
        }
    }
}
