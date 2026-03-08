import Foundation
import SwiftData

@Model
final class Interaction {
    var uuid: UUID
    var contactId: UUID
    var type: String // "call", "text", "coffee", "meeting", "email", "facetime"
    var date: Date
    var notes: String
    var createdAt: Date

    init(
        contactId: UUID,
        type: String = "call",
        date: Date = Date(),
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.contactId = contactId
        self.type = type
        self.date = date
        self.notes = notes
        self.createdAt = Date()
    }

    var typeIcon: String {
        switch type {
        case "call": return "phone.fill"
        case "text": return "message.fill"
        case "coffee": return "cup.and.saucer.fill"
        case "meeting": return "person.2.fill"
        case "email": return "envelope.fill"
        case "facetime": return "video.fill"
        default: return "bubble.left.fill"
        }
    }

    var typeLabel: String {
        type.capitalized
    }
}
