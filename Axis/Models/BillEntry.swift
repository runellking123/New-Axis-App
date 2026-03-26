import Foundation
import SwiftData

@Model
final class BillEntry {
    var uuid: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var dueDay: Int = 1
    var category: String = "other"
    var isPaid: Bool = false
    var month: Int = 0
    var year: Int = 0
    var notes: String = ""

    init(name: String, amount: Double, dueDay: Int = 1, category: String = "other", month: Int, year: Int) {
        self.uuid = UUID()
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.category = category
        self.isPaid = false
        self.month = month
        self.year = year
    }
}
