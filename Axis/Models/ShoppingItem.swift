import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var uuid: UUID
    var name: String
    var isChecked: Bool
    var listId: UUID
    var sortOrder: Int
    var createdAt: Date

    init(
        name: String,
        isChecked: Bool = false,
        listId: UUID,
        sortOrder: Int = 0
    ) {
        self.uuid = UUID()
        self.name = name
        self.isChecked = isChecked
        self.listId = listId
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
