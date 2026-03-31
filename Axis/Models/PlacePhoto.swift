import Foundation
import SwiftData

@Model
final class PlacePhoto {
    var uuid: UUID = UUID()
    var placeId: UUID = UUID()
    var caption: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var date: Date = Date()
    var createdAt: Date = Date()

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
