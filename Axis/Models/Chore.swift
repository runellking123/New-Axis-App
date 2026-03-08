import Foundation
import SwiftData

@Model
final class Chore {
    var uuid: UUID
    var name: String
    var assignedMemberId: UUID?
    var rotationDays: Int
    var lastRotatedAt: Date?
    var createdAt: Date

    init(
        name: String,
        assignedMemberId: UUID? = nil,
        rotationDays: Int = 7,
        lastRotatedAt: Date? = nil
    ) {
        self.uuid = UUID()
        self.name = name
        self.assignedMemberId = assignedMemberId
        self.rotationDays = rotationDays
        self.lastRotatedAt = lastRotatedAt
        self.createdAt = Date()
    }
}
