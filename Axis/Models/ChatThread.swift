import Foundation
import SwiftData

@Model
final class ChatThread {
    var uuid: UUID = UUID()
    var title: String = "New Chat"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var modelUsed: String = ""

    init(title: String = "New Chat", modelUsed: String = "") {
        self.uuid = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelUsed = modelUsed
    }
}
