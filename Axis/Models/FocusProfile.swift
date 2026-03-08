import Foundation
import SwiftData

@Model
final class FocusProfile {
    var uuid: UUID
    var name: String
    var durationMinutes: Int
    var soundVolumes: [String: Float] // sound name -> volume (0.0 - 1.0)
    var createdAt: Date

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
