import Foundation
import SwiftData

@Model
final class ShoppingList {
    var uuid: UUID = UUID()
    var name: String = ""
    var category: String = "" // "grocery", "household", "school"
    var createdAt: Date = Date()

    init(
        name: String,
        category: String = "grocery"
    ) {
        self.uuid = UUID()
        self.name = name
        self.category = category
        self.createdAt = Date()
    }

    var categoryIcon: String {
        switch category {
        case "grocery": return "cart.fill"
        case "household": return "house.fill"
        case "school": return "backpack.fill"
        default: return "bag.fill"
        }
    }
}
