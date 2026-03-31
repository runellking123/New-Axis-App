import Foundation
import SwiftData

@Model
final class FocusProfile {
    var uuid: UUID = UUID()
    var name: String = ""
    var durationMinutes: Int = 0
    var soundVolumes: [String: Float] = [:] // sound name -> volume (0.0 - 1.0)
    var createdAt: Date = Date()

    init(
        name: String,
        durationMinutes: Int = 25,
        soundVolumes: [String: Float] = [:]
    ) {
        self.uuid = UUID()
        self.name = name
        self.durationMinutes = durationMinutes
        self.soundVolumes = soundVolumes
        self.createdAt = Date()
    }
}
