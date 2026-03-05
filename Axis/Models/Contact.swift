import Foundation
import SwiftData

@Model
final class Contact {
    var uuid: UUID
    var name: String
    var tier: String // "innerCircle", "closeFriends", "extended"
    var phone: String
    var email: String
    var birthday: Date?
    var lastContacted: Date?
    var checkInDays: Int // cadence in days
    var notes: String
    var relationship: String // "friend", "colleague", "family", "mentor"
    var createdAt: Date

    init(
        name: String,
        tier: String = "closeFriends",
        phone: String = "",
        email: String = "",
        birthday: Date? = nil,
        lastContacted: Date? = nil,
        checkInDays: Int = 30,
        notes: String = "",
        relationship: String = "friend"
    ) {
        self.uuid = UUID()
        self.name = name
        self.tier = tier
        self.phone = phone
        self.email = email
        self.birthday = birthday
        self.lastContacted = lastContacted
        self.checkInDays = checkInDays
        self.notes = notes
        self.relationship = relationship
        self.createdAt = Date()
    }

    var tierLabel: String {
        switch tier {
        case "innerCircle": return "Inner Circle"
        case "closeFriends": return "Close Friends"
        case "extended": return "Extended"
        default: return tier
        }
    }

    var tierIcon: String {
        switch tier {
        case "innerCircle": return "star.circle.fill"
        case "closeFriends": return "heart.circle.fill"
        case "extended": return "person.circle.fill"
        default: return "person.circle"
        }
    }

    var isOverdue: Bool {
        guard let last = lastContacted else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return daysSince >= checkInDays
    }

    var daysSinceContact: Int {
        guard let last = lastContacted else { return 999 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    }

    var daysUntilBirthday: Int? {
        guard let birthday else { return nil }
        let cal = Calendar.current
        let today = Date()
        var nextBirthday = cal.date(from: DateComponents(
            year: cal.component(.year, from: today),
            month: cal.component(.month, from: birthday),
            day: cal.component(.day, from: birthday)
        ))!
        if nextBirthday < today {
            nextBirthday = cal.date(byAdding: .year, value: 1, to: nextBirthday)!
        }
        return cal.dateComponents([.day], from: today, to: nextBirthday).day
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }
}
