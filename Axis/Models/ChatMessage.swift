import Foundation
import SwiftData

@Model
final class ChatMessage {
    var uuid: UUID = UUID()
    var role: String = "user"
    var content: String = ""
    var model: String = ""
    var timestamp: Date = Date()
    var threadId: UUID?

    init(role: String, content: String, model: String = "", threadId: UUID? = nil) {
        self.uuid = UUID()
        self.role = role
        self.content = content
        self.model = model
        self.timestamp = Date()
        self.threadId = threadId
    }
}
