import Foundation
import SwiftData

@Model
final class DadWin {
    var uuid: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var mood: String = "" // "proud", "grateful", "joyful", "peaceful", "accomplished"
    var date: Date = Date()
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var photoData: Data?

    init(
        title: String,
        details: String = "",
        mood: String = "proud",
        date: Date = Date(),
        photoData: Data? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.details = details
        self.mood = mood
        self.date = date
        self.createdAt = Date()
        self.photoData = photoData
    }

    var moodEmoji: String {
        switch mood {
        case "proud": return "star.fill"
        case "grateful": return "heart.fill"
        case "joyful": return "face.smiling.inverse"
        case "peaceful": return "leaf.fill"
        case "accomplished": return "trophy.fill"
        default: return "star.fill"
        }
    }

    var moodLabel: String {
        mood.capitalized
    }
}
