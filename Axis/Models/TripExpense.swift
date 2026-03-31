import Foundation
import SwiftData

@Model
final class TripExpense {
    var uuid: UUID = UUID()
    var tripId: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var category: String = ""    // flight, hotel, food, transport, activities, other
    var date: Date = Date()
    var notes: String = ""

    init(
        tripId: UUID,
        name: String,
        amount: Double,
        category: String = "other",
        date: Date = Date(),
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.tripId = tripId
        self.name = name
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
    }

    var categoryIcon: String {
        switch category {
        case "flight": return "airplane"
        case "hotel": return "bed.double.fill"
        case "food": return "fork.knife"
        case "transport": return "car.fill"
        case "activities": return "ticket.fill"
        default: return "dollarsign.circle"
        }
    }
}
