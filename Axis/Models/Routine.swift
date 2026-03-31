import Foundation
import SwiftData

@Model
final class Routine {
    var uuid: UUID = UUID()
    var name: String = ""
    var timeOfDay: String = "" // "morning", "afternoon", "evening"
    var createdAt: Date = Date()

    init(
        name: String = "",
        timeOfDay: String = "morning"
    ) {
        self.uuid = UUID()
        self.name = name
        self.timeOfDay = timeOfDay
        self.createdAt = Date()
    }
}
