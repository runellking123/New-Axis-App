import Foundation
import SwiftData

@Model
final class WaterEntry {
    var uuid: UUID = UUID()
    var amountOz: Int = 0
    var date: Date = Date()
    var createdAt: Date = Date()

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
