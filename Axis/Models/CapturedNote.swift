import Foundation
import SwiftData

@Model
final class CapturedNote {
    var title: String = ""
    var content: String = ""
    var transcribedFromVoice: Bool = false
    var classifiedModule: String = ""
    var isProcessed: Bool = false
    var isPinned: Bool = false
    var color: String = ""
    @Attribute(originalName: "folder") var folder: String? = "Personal"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        title: String = "",
        content: String = "",
        transcribedFromVoice: Bool = false,
        classifiedModule: String = "uncategorized",
        isProcessed: Bool = false,
        isPinned: Bool = false,
        color: String = "yellow",
        folder: String = "Personal"
    ) {
        self.title = title
        self.content = content
        self.transcribedFromVoice = transcribedFromVoice
        self.classifiedModule = classifiedModule
        self.isProcessed = isProcessed
        self.isPinned = isPinned
        self.color = color
        self.folder = folder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var resolvedFolder: String {
        folder ?? "Personal"
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let firstLine = content.components(separatedBy: .newlines).first, !firstLine.isEmpty {
            return String(firstLine.prefix(50))
        }
        return "Untitled Note"
    }

    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        let startIndex = title.isEmpty ? 1 : 0
        let previewLines = lines.dropFirst(startIndex).prefix(3).joined(separator: " ")
        return String(previewLines.prefix(120))
    }

    var noteColor: String { color }

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
