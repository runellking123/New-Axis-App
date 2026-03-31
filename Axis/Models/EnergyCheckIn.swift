import Foundation
import SwiftData

@Model
final class EnergyCheckIn {
    var uuid: UUID = UUID()
    var level: Int = 0          // 1-10
    var note: String = ""
    var timestamp: Date = Date()

    init(level: Int, note: String = "") {
        self.uuid = UUID()
        self.level = max(1, min(10, level))
        self.note = note
        self.timestamp = Date()
    }
}
