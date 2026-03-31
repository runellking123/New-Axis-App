import Foundation
import SwiftData

@Model
final class MealPlan {
    var dayOfWeek: Int = 0 // 1=Sunday, 2=Monday, ... 7=Saturday
    var mealType: String = "" // "breakfast", "lunch", "dinner"
    var mealName: String = ""
    var weekStartDate: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        dayOfWeek: Int,
        mealType: String = "dinner",
        mealName: String = "",
        weekStartDate: Date = Date(),
        notes: String = ""
    ) {
        self.dayOfWeek = dayOfWeek
        self.mealType = mealType
        self.mealName = mealName
        self.weekStartDate = weekStartDate
        self.notes = notes
        self.createdAt = Date()
    }

    var dayLabel: String {
        switch dayOfWeek {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "?"
        }
    }

    var mealIcon: String {
        switch mealType {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        default: return "fork.knife"
        }
    }
}
