import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    func scheduleDayBrief(at wakeTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "Your Day Brief is ready. Tap to see today's priorities."
        content.sound = .default
        content.categoryIdentifier = "DAY_BRIEF"

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "day-brief",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDeadlineEscalation(title: String, dueDate: Date, identifier: String) {
        let calendar = Calendar.current

        // 72 hours: yellow alert
        if let yellowDate = calendar.date(byAdding: .hour, value: -72, to: dueDate), yellowDate > Date() {
            scheduleAlert(
                title: "Upcoming: \(title)",
                body: "Due in 3 days. Time to make progress.",
                date: yellowDate,
                identifier: "\(identifier)-72h",
                urgency: "yellow"
            )
        }

        // 24 hours: amber alert
        if let amberDate = calendar.date(byAdding: .hour, value: -24, to: dueDate), amberDate > Date() {
            scheduleAlert(
                title: "Tomorrow: \(title)",
                body: "Due in 24 hours. Prioritize this today.",
                date: amberDate,
                identifier: "\(identifier)-24h",
                urgency: "amber"
            )
        }

        // 2 hours: red alert
        if let redDate = calendar.date(byAdding: .hour, value: -2, to: dueDate), redDate > Date() {
            scheduleAlert(
                title: "URGENT: \(title)",
                body: "Due in 2 hours!",
                date: redDate,
                identifier: "\(identifier)-2h",
                urgency: "red"
            )
        }
    }

    private func scheduleAlert(title: String, body: String, date: Date, identifier: String, urgency: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = urgency == "red" ? .defaultCritical : .default
        content.categoryIdentifier = "DEADLINE_\(urgency.uppercased())"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
