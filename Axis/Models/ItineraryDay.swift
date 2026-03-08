import Foundation
import SwiftData

@Model
final class ItineraryDay {
    var uuid: UUID
    var tripId: UUID
    var dayNumber: Int
    var date: Date
    var placeIds: [UUID]
    var notes: String
    var createdAt: Date

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
