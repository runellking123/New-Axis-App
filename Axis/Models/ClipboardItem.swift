import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var uuid: UUID = UUID()
    var content: String = ""
    var title: String = ""
    var itemType: String = ""  // "link", "text", "snippet"
    var tags: [String] = []
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    init(
        content: String,
        title: String = "",
        itemType: String = "text",
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        self.uuid = UUID()
        self.content = content
        self.title = title
        self.itemType = itemType
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = Date()
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if itemType == "link" {
            return content.components(separatedBy: "/").last ?? content
        }
        return String(content.prefix(60))
    }

    var icon: String {
        switch itemType {
        case "link": return "link"
        case "snippet": return "doc.text"
        default: return "doc.on.clipboard"
        }
    }

    var isLink: Bool {
        content.hasPrefix("http://") || content.hasPrefix("https://")
    }
}
