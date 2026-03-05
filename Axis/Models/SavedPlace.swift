import Foundation
import SwiftData

@Model
final class SavedPlace {
    var uuid: UUID
    var name: String
    var category: String // "dining", "events", "activities", "travel"
    var address: String
    var notes: String
    var rating: Int // 1-5
    var isVisited: Bool
    var isFavorite: Bool
    var createdAt: Date

    init(
        name: String,
        category: String = "dining",
        address: String = "",
        notes: String = "",
        rating: Int = 0,
        isVisited: Bool = false,
        isFavorite: Bool = false
    ) {
        self.uuid = UUID()
        self.name = name
        self.category = category
        self.address = address
        self.notes = notes
        self.rating = rating
        self.isVisited = isVisited
        self.isFavorite = isFavorite
        self.createdAt = Date()
    }

    var categoryIcon: String {
        switch category {
        case "dining": return "fork.knife"
        case "events": return "ticket.fill"
        case "activities": return "figure.hiking"
        case "travel": return "airplane"
        default: return "mappin"
        }
    }

    var categoryLabel: String {
        category.capitalized
    }
}
