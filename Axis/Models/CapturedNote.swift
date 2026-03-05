import Foundation
import SwiftData

@Model
final class CapturedNote {
    var content: String
    var transcribedFromVoice: Bool
    var classifiedModule: String
    var isProcessed: Bool
    var createdAt: Date

    init(
        content: String,
        transcribedFromVoice: Bool = false,
        classifiedModule: String = "commandCenter",
        isProcessed: Bool = false
    ) {
        self.content = content
        self.transcribedFromVoice = transcribedFromVoice
        self.classifiedModule = classifiedModule
        self.isProcessed = isProcessed
        self.createdAt = Date()
    }

    var moduleIcon: String {
        switch classifiedModule {
        case "commandCenter": return "bolt.fill"
        case "workSuite": return "building.columns.fill"
        case "familyHQ": return "house.fill"
        case "socialCircle": return "person.2.fill"
        case "explore": return "safari.fill"
        case "balance": return "heart.fill"
        default: return "note.text"
        }
    }

    var moduleLabel: String {
        switch classifiedModule {
        case "commandCenter": return "Command Center"
        case "workSuite": return "Work Suite"
        case "familyHQ": return "Family HQ"
        case "socialCircle": return "Social Circle"
        case "explore": return "Explore"
        case "balance": return "Balance"
        default: return "Uncategorized"
        }
    }
}
