import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    private func log(_ message: String) {
        #if DEBUG
        print("[NotificationService] \(message)")
        #endif
    }

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

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("Failed to schedule day brief notification: \(error.localizedDescription)")
            }
        }
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
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("Failed to schedule alert \(identifier): \(error.localizedDescription)")
            }
        }
    }

    func scheduleCheckInReminders() {
        // Remove old check-in reminders
        cancelAll(withPrefix: "checkin-")

        let contacts = PersistenceService.shared.fetchContacts()
        let calendar = Calendar.current

        for contact in contacts {
            let daysSince: Int
            if let last = contact.lastContacted {
                daysSince = calendar.dateComponents([.day], from: last, to: Date()).day ?? 0
            } else {
                daysSince = contact.checkInDays // treat as already overdue
            }

            let daysUntilDue = contact.checkInDays - daysSince
            // Schedule if due within the next 24 hours or already overdue
            if daysUntilDue <= 1 {
                let content = UNMutableNotificationContent()
                content.title = "Time to check in"
                content.body = "It's been \(daysSince) days since you talked to \(contact.name). Send a quick text?"
                content.sound = .default
                content.categoryIdentifier = "CHECK_IN"

                // Schedule for 9 AM tomorrow if overdue, or 9 AM on due date
                var triggerDate = calendar.startOfDay(for: Date())
                triggerDate = calendar.date(byAdding: .hour, value: 9, to: triggerDate) ?? triggerDate
                if triggerDate < Date() {
                    triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
                }

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "checkin-\(contact.uuid.uuidString)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { [weak self] error in
                    if let error {
                        self?.log("Failed to schedule check-in for \(contact.name): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func cancelAll(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - EA Smart Notifications

    /// Quiet hours check
    func isInQuietHours(start: Int = 20, end: Int = 7) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= start || hour < end
    }

    func scheduleDailyPlanReady(at time: Date) {
        cancelAll(withPrefix: "ea-plan-ready")
        let content = UNMutableNotificationContent()
        content.title = "Your daily plan is ready"
        content.body = "Tap to see your AI-generated schedule for today."
        content.sound = .default
        content.categoryIdentifier = "EA_PLAN_READY"
        content.threadIdentifier = "ea-planner"

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "ea-plan-ready", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDeadlineWarning(taskTitle: String, taskId: UUID, deadline: Date) {
        let calendar = Calendar.current

        // 72 hours before
        if let warn72 = calendar.date(byAdding: .hour, value: -72, to: deadline), warn72 > Date() {
            scheduleEAAlert(
                title: "Deadline approaching",
                body: "\"\(taskTitle)\" is due in 3 days",
                date: warn72,
                identifier: "ea-deadline-\(taskId.uuidString)-72h",
                category: "EA_DEADLINE",
                threadId: "ea-tasks"
            )
        }

        // 24 hours before
        if let warn24 = calendar.date(byAdding: .hour, value: -24, to: deadline), warn24 > Date() {
            scheduleEAAlert(
                title: "Due tomorrow",
                body: "\"\(taskTitle)\" is due in 24 hours. Prioritize this today.",
                date: warn24,
                identifier: "ea-deadline-\(taskId.uuidString)-24h",
                category: "EA_DEADLINE_URGENT",
                threadId: "ea-tasks"
            )
        }
    }

    func scheduleFocusBlockStart(taskTitle: String, startTime: Date) {
        guard startTime > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus block starting"
        content.body = "Time for deep work: \(taskTitle)"
        content.sound = .default
        content.categoryIdentifier = "EA_FOCUS_START"
        content.threadIdentifier = "ea-planner"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "ea-focus-\(startTime.timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleMeetingReminder(title: String, eventId: String, startTime: Date) {
        let calendar = Calendar.current

        // 60 min before
        if let remind60 = calendar.date(byAdding: .minute, value: -60, to: startTime), remind60 > Date() {
            scheduleEAAlert(
                title: "Meeting in 1 hour",
                body: title,
                date: remind60,
                identifier: "ea-meeting-\(eventId)-60m",
                category: "EA_MEETING",
                threadId: "ea-calendar"
            )
        }

        // 15 min before
        if let remind15 = calendar.date(byAdding: .minute, value: -15, to: startTime), remind15 > Date() {
            scheduleEAAlert(
                title: "Meeting in 15 minutes",
                body: title,
                date: remind15,
                identifier: "ea-meeting-\(eventId)-15m",
                category: "EA_MEETING",
                threadId: "ea-calendar"
            )
        }
    }

    func scheduleAtRiskTaskAlert(taskTitle: String, taskId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "At-risk task"
        content.body = "\"\(taskTitle)\" has a deadline approaching with no scheduled time."
        content.sound = .default
        content.categoryIdentifier = "EA_AT_RISK"
        content.threadIdentifier = "ea-tasks"

        // Fire in 5 seconds (immediate notification)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "ea-atrisk-\(taskId.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleInboxPending(count: Int) {
        cancelAll(withPrefix: "ea-inbox")
        guard count > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Inbox items pending"
        content.body = "\(count) unreviewed item\(count == 1 ? "" : "s") in your inbox."
        content.sound = .default
        content.categoryIdentifier = "EA_INBOX"
        content.threadIdentifier = "ea-inbox"

        // Schedule for 9 AM
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "ea-inbox-pending", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleEAAlert(title: String, body: String, date: Date, identifier: String, category: String, threadId: String) {
        guard !isInQuietHours() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.threadIdentifier = threadId

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("Failed to schedule EA alert \(identifier): \(error.localizedDescription)")
            }
        }
    }
}
