import Foundation
import SwiftData

@Model
final class ItineraryDay {
    var uuid: UUID = UUID()
    var tripId: UUID = UUID()
    var dayNumber: Int = 0
    var date: Date = Date()
    var placeIds: [UUID] = []
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        tripId: UUID,
        dayNumber: Int,
        date: Date = Date(),
        placeIds: [UUID] = [],
        notes: String = ""
    ) {
        self.uuid = UUID()
        self.tripId = tripId
        self.dayNumber = dayNumber
        self.date = date
        self.placeIds = placeIds
        self.notes = notes
        self.createdAt = Date()
    }
}
