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

    func uncompleteReminder(id: String) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        item.isCompleted = false
        do { try store.save(item, commit: true); return true } catch { return false }
    }

    func deleteReminder(id: String) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        do { try store.remove(item, commit: true); return true } catch { return false }
    }

    /// Creates a new reminder. `meetingInfo` is stored in notes as a delimited
    /// section so the detail sheet and link detector can find it later.
    @discardableResult
    func createReminder(
        title: String,
        notes: String? = nil,
        meetingInfo: String? = nil,
        dueDate: Date? = nil,
        includeDueTime: Bool = false,
        priority: Int = 0
    ) -> String? {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return nil }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.priority = priority
        reminder.calendar = store.defaultCalendarForNewReminders()
        reminder.notes = AxisReminderNotes.encode(notes: notes, meetingInfo: meetingInfo)
        if let dueDate {
            var comps: Set<Calendar.Component> = [.year, .month, .day]
            if includeDueTime { comps.formUnion([.hour, .minute]) }
            reminder.dueDateComponents = Calendar.current.dateComponents(comps, from: dueDate)
            if includeDueTime {
                let alarm = EKAlarm(absoluteDate: dueDate)
                reminder.addAlarm(alarm)
            }
        }
        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            return nil
        }
    }

    /// Updates any subset of fields on an existing reminder.
    @discardableResult
    func updateReminder(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        meetingInfo: String? = nil,
        dueDate: Date? = nil,
        clearDueDate: Bool = false,
        includeDueTime: Bool? = nil,
        priority: Int? = nil,
        isCompleted: Bool? = nil
    ) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        if let title { reminder.title = title }
        if notes != nil || meetingInfo != nil {
            // Preserve whichever half wasn't provided by decoding current notes first.
            let current = AxisReminderNotes.decode(reminder.notes)
            reminder.notes = AxisReminderNotes.encode(
                notes: notes ?? current.notes,
                meetingInfo: meetingInfo ?? current.meetingInfo
            )
        }
        if clearDueDate {
            reminder.dueDateComponents = nil
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
        } else if let dueDate {
            let wantsTime = includeDueTime ?? (reminder.dueDateComponents?.hour != nil)
            var comps: Set<Calendar.Component> = [.year, .month, .day]
            if wantsTime { comps.formUnion([.hour, .minute]) }
            reminder.dueDateComponents = Calendar.current.dateComponents(comps, from: dueDate)
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
            if wantsTime {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        }
        if let priority { reminder.priority = priority }
        if let isCompleted { reminder.isCompleted = isCompleted }
        do { try store.save(reminder, commit: true); return true } catch { return false }
    }

    /// Fetches every incomplete reminder regardless of due date and groups them
    /// into Overdue / Today / Upcoming / No Date buckets for the Workflow UI.
    func fetchAllReminders() async -> [ReminderItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let predicate = store.predicateForReminders(in: nil)
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
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                calendarTitle: reminder.calendar?.title
            )
        }
    }

    /// Returns the full notes (structured: user notes + meeting info) for a reminder by id.
    func reminderDetails(id: String) -> (notes: String?, meetingInfo: String?)? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return AxisReminderNotes.decode(reminder.notes)
    }

    /// Creates a calendar event that mirrors a reminder — title, date/time, and
    /// notes (including meeting info). Returns the new event identifier.
    @discardableResult
    func createEventFromReminder(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        meetingInfo: String? = nil
    ) -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = AxisReminderNotes.encode(notes: notes, meetingInfo: meetingInfo)
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.calendarItemIdentifier
        } catch {
            return nil
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

// Reminders don't have a first-class "meeting info" field, so we keep it inside
// notes using a sentinel delimiter. This lets AI Chat, the reminder detail
// sheet, and the meeting-link detector share a single source of truth.
enum AxisReminderNotes {
    private static let marker = "--- Meeting Info ---"

    static func encode(notes: String?, meetingInfo: String?) -> String? {
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedInfo = meetingInfo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedNotes.isEmpty && trimmedInfo.isEmpty { return nil }
        if trimmedInfo.isEmpty { return trimmedNotes }
        if trimmedNotes.isEmpty { return "\(marker)\n\(trimmedInfo)" }
        return "\(trimmedNotes)\n\n\(marker)\n\(trimmedInfo)"
    }

    static func decode(_ raw: String?) -> (notes: String?, meetingInfo: String?) {
        guard let raw, !raw.isEmpty else { return (nil, nil) }
        guard let range = raw.range(of: marker) else { return (raw, nil) }
        let beforeRaw = String(raw[..<range.lowerBound])
        let afterRaw = String(raw[range.upperBound...])
        let notes = beforeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = afterRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (notes.isEmpty ? nil : notes, info.isEmpty ? nil : info)
    }
}
