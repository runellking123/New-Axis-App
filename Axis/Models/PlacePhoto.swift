import Foundation
import SwiftData

@Model
final class PlacePhoto {
    var uuid: UUID
    var placeId: UUID
    var caption: String
    @Attribute(.externalStorage) var photoData: Data?
    var date: Date
    var createdAt: Date

    init(
        placeId: UUID,
        caption: String = "",
        photoData: Data? = nil,
        date: Date = Date()
    ) {
        self.uuid = UUID()
        self.placeId = placeId
        self.caption = caption
        self.photoData = photoData
        self.date = date
        self.createdAt = Date()
    }
}
