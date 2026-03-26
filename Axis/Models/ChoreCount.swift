import Foundation
import SwiftData

@Model
final class ChoreCount {
    var uuid: UUID = UUID()
    var choreName: String = ""
    var person: String = ""  // "drking" or "wife"
    var count: Int = 0
    var weekStartDate: Date = Date()

    init(choreName: String, person: String, count: Int = 0) {
        self.uuid = UUID()
        self.choreName = choreName
        self.person = person
        self.count = count
        self.weekStartDate = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!)
    }
}
