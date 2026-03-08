import Foundation
import SwiftData

@Model
final class WaterEntry {
    var uuid: UUID
    var amountOz: Int
    var date: Date
    var createdAt: Date

    init(
        amountOz: Int = 8,
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.amountOz = amountOz
        self.date = date
        self.createdAt = Date()
    }
}
