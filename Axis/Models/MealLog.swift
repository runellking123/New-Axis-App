import Foundation
import SwiftData

@Model
final class MealLog {
    var uuid: UUID = UUID()
    var mealType: String = ""   // "breakfast", "lunch", "dinner", "snack"
    var name: String = ""
    var notes: String = ""
    var calories: Int = 0
    var date: Date = Date()
    var createdAt: Date = Date()

    init(
        mealType: String = "lunch",
        name: String = "",
        notes: String = "",
        calories: Int = 0,
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.mealType = mealType
        self.name = name
        self.notes = notes
        self.calories = calories
        self.date = date
        self.createdAt = Date()
    }

    var mealIcon: String {
        switch mealType {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "cup.and.saucer.fill"
        default: return "fork.knife"
        }
    }

    var mealColor: String {
        switch mealType {
        case "breakfast": return "orange"
        case "lunch": return "yellow"
        case "dinner": return "indigo"
        case "snack": return "green"
        default: return "gray"
        }
    }
}
