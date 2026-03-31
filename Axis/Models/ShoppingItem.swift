import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var uuid: UUID = UUID()
    var name: String = ""
    var isChecked: Bool = false
    var listId: UUID = UUID()
    var sortOrder: Int = 0
    var createdAt: Date = Date()

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
