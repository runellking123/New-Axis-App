import Foundation
import SwiftData

@Model
final class EAProject {
    var uuid: UUID
    var title: String
    var projectDescription: String?
    var status: String // active, onHold, completed, archived
    var category: String // university, consulting, personal
    var isTemplate: Bool?
    var templateName: String?
    var deadline: Date?
    var statusNote: String?
    var createdAt: Date

    init(
        title: String,
        projectDescription: String? = nil,
        status: String = "active",
        category: String = "personal",
        isTemplate: Bool? = nil,
        templateName: String? = nil,
        deadline: Date? = nil,
        statusNote: String? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.projectDescription = projectDescription
        self.status = status
        self.category = category
        self.isTemplate = isTemplate
        self.templateName = templateName
        self.deadline = deadline
        self.statusNote = statusNote
        self.createdAt = Date()
    }
}
