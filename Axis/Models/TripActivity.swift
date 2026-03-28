import Foundation
import SwiftData

@Model
final class TripActivity {
    var uuid: UUID
    var tripId: UUID
    var dayNumber: Int
    var timeSlot: String    // morning, afternoon, evening
    var title: String
    var location: String
    var notes: String
    var startTime: Date?

    init(
        tripId: UUID,
        dayNumber: Int,
        timeSlot: String = "morning",
        title: String,
        location: String = "",
        notes: String = "",
        startTime: Date? = nil
    ) {
        self.uuid = UUID()
        self.tripId = tripId
        self.dayNumber = dayNumber
        self.timeSlot = timeSlot
        self.title = title
        self.location = location
        self.notes = notes
        self.startTime = startTime
    }

    var slotIcon: String {
        switch timeSlot {
        case "morning": return "sunrise.fill"
        case "afternoon": return "sun.max.fill"
        case "evening": return "moon.fill"
        default: return "clock"
        }
    }
}
