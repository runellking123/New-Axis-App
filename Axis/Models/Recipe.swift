import Foundation
import SwiftData

@Model
final class Recipe {
    var uuid: UUID
    var name: String
    var ingredients: String
    var instructions: String
    var servings: Int
    var prepTimeMinutes: Int
    var createdAt: Date

    init(
        name: String,
        ingredients: String = "",
        instructions: String = "",
        servings: Int = 4,
        prepTimeMinutes: Int = 30
    ) {
        self.uuid = UUID()
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.createdAt = Date()
    }
}
