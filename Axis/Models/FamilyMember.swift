import Foundation
import SwiftData

@Model
final class FamilyMember {
    var uuid: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var color: String = ""
    var createdAt: Date = Date()

    init(
        name: String,
        emoji: String = "\u{1F464}",
        color: String = "blue"
    ) {
        self.uuid = UUID()
        self.name = name
        self.emoji = emoji
        self.color = color
        self.createdAt = Date()
    }
}
