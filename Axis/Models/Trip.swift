import Foundation
import SwiftData

@Model
final class Trip {
    var uuid: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var budgetPlanned: Double
    var budgetSpent: Double
    var notes: String
    var createdAt: Date

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
