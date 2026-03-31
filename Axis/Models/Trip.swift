import Foundation
import SwiftData

@Model
final class Trip {
    var uuid: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var budgetPlanned: Double = 0
    var budgetSpent: Double = 0
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        name: String,
        startDate: Date = Date(),
        endDate: Date = Date(),
        budgetPlanned: Double = 0,
        budgetSpent: Double = 0,
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.budgetPlanned = budgetPlanned
        self.budgetSpent = budgetSpent
        self.notes = notes
        self.createdAt = Date()
    }

    var budgetRemaining: Double {
        budgetPlanned - budgetSpent
    }

    var isActive: Bool {
        let today = Date()
        return today >= startDate && today <= endDate
    }
}
