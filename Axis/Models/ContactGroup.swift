import Foundation
import SwiftData

@Model
final class ContactGroup {
    var uuid: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var memberIds: [UUID] = []
    var createdAt: Date = Date()

    init(
        name: String,
        emoji: String = "👥",
        memberIds: [UUID] = []
    ) {
        self.uuid = UUID()
        self.name = name
        self.emoji = emoji
        self.memberIds = memberIds
        self.createdAt = Date()
    }
}
