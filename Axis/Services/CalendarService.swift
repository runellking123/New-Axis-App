import EventKit
import Foundation

@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var todayEvents: [CalendarEvent] = []

    struct CalendarEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let calendarColor: String
        let isAllDay: Bool

        var duration: TimeInterval {
            endDate.timeIntervalSince(startDate)
        }

        var formattedTime: String {
            if isAllDay { return "All Day" }
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        let current = EKEventStore.authorizationStatus(for: .event)
        if current == .fullAccess {
            await MainActor.run { self.authorizationStatus = current }
            return true
        }
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = granted ? .fullAccess : .denied
            }
            return granted
        } catch {
            await MainActor.run { self.authorizationStatus = .denied }
            return false
        }
    }

    func fetchTodayEvents() async {
        let current = EKEventStore.authorizationStatus(for: .event)
        await MainActor.run { self.authorizationStatus = current }
        guard current == .fullAccess else {
            await MainActor.run { self.todayEvents = [] }
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        let mapped = ekEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                calendarColor: event.calendar?.cgColor?.components?.description ?? "blue",
                isAllDay: event.isAllDay
            )
        }.sorted { $0.startDate < $1.startDate }

        await MainActor.run {
            self.todayEvents = mapped
        }
    }

    func upcomingEvent() -> CalendarEvent? {
        let now = Date()
        return todayEvents.first { $0.startDate > now }
    }

    func currentEvent() -> CalendarEvent? {
        let now = Date()
        return todayEvents.first { $0.startDate <= now && $0.endDate > now }
    }

    // MARK: - Reminders

    struct ReminderItem: Identifiable, Equatable {
        let id: String
        let title: String
        let dueDate: Date?
        let hasDueTime: Bool
        let isCompleted: Bool
        let priority: Int
        let calendarTitle: String?
    }

    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToReminders()
            return granted
        } catch {
            return false
        }
    }

    func fetchTodayReminders() async -> [ReminderItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForReminders(in: nil)
        let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        return reminders
            .filter { reminder in
                guard let due = reminder.dueDateComponents, let dueDate = calendar.date(from: due) else { return false }
                return dueDate >= startOfDay && dueDate < endOfDay
            }
            .map { reminder in
                let dueDate = reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
                return ReminderItem(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title ?? "Untitled",
                    dueDate: dueDate,
                    hasDueTime: reminder.dueDateComponents?.hour != nil || reminder.dueDateComponents?.minute != nil,
                    isCompleted: reminder.isCompleted,
                    priority: reminder.priority,
                    calendarTitle: reminder.calendar?.title
                )
            }
    }

    func fetchIncompleteReminders() async -> [ReminderItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }
        let calendar = Calendar.current
        return reminders.map { reminder in
            let dueDate = reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
            return ReminderItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "Untitled",
                dueDate: dueDate,
                hasDueTime: reminder.dueDateComponents?.hour != nil || reminder.dueDateComponents?.minute != nil,
                isCompleted: false,
                priority: reminder.priority,
                calendarTitle: reminder.calendar?.title
            )
        }
    }

    func completeReminder(id: String) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        item.isCompleted = true
        do {
            try store.save(item, commit: true)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Calendar Creation & Time Blocks

    func createAxisCalendar() -> EKCalendar? {
        // Check if Axis calendar already exists
        let calendars = store.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == "Axis" }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Axis"
        calendar.source = store.defaultCalendarForNewEvents?.source

        guard calendar.source != nil else { return nil }
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    func createTimeBlock(title: String, start: Date, end: Date, notes: String? = nil) -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        guard let calendar = createAxisCalendar() else { return nil }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = notes
        event.calendar = calendar

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func fetchEvents(start: Date, end: Date) -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map { event in
            CalendarEvent(
                // calendarItemIdentifier is stable across recurring-event occurrences
                // and works reliably with EKEventStore.calendarItem(withIdentifier:)
                // when looking up the source EKEvent later (e.g., from the planner
                // detail sheet when surfacing notes / Zoom links from Outlook).
                id: event.calendarItemIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                calendarColor: event.calendar?.cgColor?.components?.description ?? "blue",
                isAllDay: event.isAllDay
            )
        }.sorted { $0.startDate < $1.startDate }
    }
}
