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
        let calendarIdentifier: String
        let calendarTitle: String
        let sourceTitle: String
        let sourceType: String

        var duration: TimeInterval {
            endDate.timeIntervalSince(startDate)
        }

        var formattedTime: String {
            if isAllDay { return "All Day" }
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }

        /// Compact label like "Work · Outlook" for UI badges.
        var sourceBadge: String {
            if sourceTitle.isEmpty || sourceTitle == calendarTitle {
                return calendarTitle
            }
            return "\(calendarTitle) · \(sourceTitle)"
        }
    }

    /// A user-visible EventKit calendar with its account/source identity.
    struct CalendarInfo: Identifiable, Equatable, Hashable {
        let id: String
        let title: String
        let sourceTitle: String
        let sourceType: String
        let allowsContentModifications: Bool
        let isDefault: Bool
        let colorComponents: [CGFloat]

        var isIncludedInAnalysis: Bool {
            CalendarSelectionPreferences.isIncluded(id)
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

        let mapped = fetchEvents(start: startOfDay, end: endOfDay)

        await MainActor.run {
            self.todayEvents = mapped
        }
    }

    // MARK: - Calendar Catalog & Selection

    func availableCalendars() -> [CalendarInfo] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess
                || EKEventStore.authorizationStatus(for: .event) == .writeOnly else {
            return []
        }
        let defaultID = store.defaultCalendarForNewEvents?.calendarIdentifier
        return store.calendars(for: .event)
            .map { cal in
                CalendarInfo(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    sourceTitle: cal.source.title,
                    sourceType: Self.displayName(for: cal.source.sourceType),
                    allowsContentModifications: cal.allowsContentModifications,
                    isDefault: cal.calendarIdentifier == defaultID,
                    colorComponents: Self.rgbaComponents(from: cal.cgColor)
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle != rhs.sourceTitle {
                    return lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle) == .orderedAscending
                }
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    /// Calendars that should feed Day Brief, daily plans, and schedule analysis.
    /// Returns `nil` when every calendar should be included (EventKit default).
    func calendarsForAnalysis() -> [EKCalendar]? {
        guard let included = CalendarSelectionPreferences.includedCalendarIDs else {
            return nil
        }
        let match = store.calendars(for: .event).filter { included.contains($0.calendarIdentifier) }
        return match
    }

    static func displayName(for sourceType: EKSourceType) -> String {
        switch sourceType {
        case .local: return "On My iPhone"
        case .exchange: return "Exchange / Outlook"
        case .calDAV: return "CalDAV / Google"
        case .mobileMe: return "iCloud"
        case .subscribed: return "Subscribed"
        case .birthdays: return "Birthdays"
        @unknown default: return "Other"
        }
    }

    private static func rgbaComponents(from color: CGColor?) -> [CGFloat] {
        guard let color, let comps = color.components, !comps.isEmpty else {
            return [0.2, 0.5, 0.9, 1.0]
        }
        if comps.count >= 4 { return Array(comps.prefix(4)) }
        if comps.count == 2 { return [comps[0], comps[0], comps[0], comps[1]] }
        return [0.2, 0.5, 0.9, 1.0]
    }

    private func mapEvent(_ event: EKEvent) -> CalendarEvent {
        let cal = event.calendar
        return CalendarEvent(
            id: event.calendarItemIdentifier,
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            calendarColor: cal?.cgColor?.components?.description ?? "blue",
            isAllDay: event.isAllDay,
            calendarIdentifier: cal?.calendarIdentifier ?? "",
            calendarTitle: cal?.title ?? "Calendar",
            sourceTitle: cal?.source.title ?? "",
            sourceType: cal.map { Self.displayName(for: $0.source.sourceType) } ?? ""
        )
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
        let calendarIdentifier: String?
        let recurrenceSummary: String?
        let labels: [String]
    }

    /// A user-visible Reminders list (an EKCalendar of type .reminder).
    struct ReminderList: Identifiable, Equatable, Hashable {
        let id: String
        let title: String
        let isDefault: Bool
    }

    func availableReminderLists() -> [ReminderList] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let defaultID = store.defaultCalendarForNewReminders()?.calendarIdentifier
        return store.calendars(for: .reminder)
            .map { cal in
                ReminderList(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    isDefault: cal.calendarIdentifier == defaultID
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    /// Simple presets surfaced in the editor. Power-user custom rules can be
    /// added later; these cover the >90% case (matches Apple Reminders UI).
    enum RecurrencePreset: String, CaseIterable, Identifiable {
        case none, daily, weekdays, weekly, monthly, yearly
        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "Never"
            case .daily: return "Every Day"
            case .weekdays: return "Every Weekday"
            case .weekly: return "Every Week"
            case .monthly: return "Every Month"
            case .yearly: return "Every Year"
            }
        }

        func buildRule() -> EKRecurrenceRule? {
            switch self {
            case .none:
                return nil
            case .daily:
                return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
            case .weekdays:
                let days: [EKRecurrenceDayOfWeek] = [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)]
                return EKRecurrenceRule(
                    recurrenceWith: .weekly,
                    interval: 1,
                    daysOfTheWeek: days,
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: nil
                )
            case .weekly:
                return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
            case .monthly:
                return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
            case .yearly:
                return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
            }
        }

        static func detect(from rule: EKRecurrenceRule?) -> RecurrencePreset {
            guard let rule, rule.interval == 1, rule.recurrenceEnd == nil else {
                return rule == nil ? .none : .none // unknown / custom rules fall back to None in the picker
            }
            switch rule.frequency {
            case .daily: return .daily
            case .weekly:
                let weekdaysSet: Set<EKWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
                if let days = rule.daysOfTheWeek, !days.isEmpty {
                    let set = Set(days.map(\.dayOfTheWeek))
                    if set == weekdaysSet { return .weekdays }
                    return .weekly
                }
                return .weekly
            case .monthly: return .monthly
            case .yearly: return .yearly
            @unknown default: return .none
            }
        }

        static func summary(for rule: EKRecurrenceRule?) -> String? {
            guard let rule else { return nil }
            let preset = detect(from: rule)
            if preset != .none { return preset.label }
            // Fallback for custom rules we don't have a preset for yet.
            switch rule.frequency {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            @unknown default: return "Repeats"
            }
        }
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
                    calendarTitle: reminder.calendar?.title,
                    calendarIdentifier: reminder.calendar?.calendarIdentifier,
                    recurrenceSummary: RecurrencePreset.summary(for: reminder.recurrenceRules?.first),
                    labels: AxisReminderNotes.decodeAll(reminder.notes).labels
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
                calendarTitle: reminder.calendar?.title,
                calendarIdentifier: reminder.calendar?.calendarIdentifier,
                recurrenceSummary: RecurrencePreset.summary(for: reminder.recurrenceRules?.first),
                labels: AxisReminderNotes.decodeAll(reminder.notes).labels
            )
        }
    }

    func completeReminder(id: String) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }

        // Recurring reminders behave like Apple Reminders.app: completing one
        // advances the due date to the next occurrence rather than marking it
        // permanently done. The historical occurrence is "lost" the same way
        // it is in the system app — adequate for habit-style reminders.
        if let rule = item.recurrenceRules?.first,
           let currentDue = item.dueDateComponents.flatMap({ Calendar.current.date(from: $0) }),
           let next = nextOccurrence(after: currentDue, rule: rule) {
            let hasTime = item.dueDateComponents?.hour != nil || item.dueDateComponents?.minute != nil
            var comps: Set<Calendar.Component> = [.year, .month, .day]
            if hasTime { comps.formUnion([.hour, .minute]) }
            item.dueDateComponents = Calendar.current.dateComponents(comps, from: next)
            item.alarms?.forEach { item.removeAlarm($0) }
            if hasTime {
                item.addAlarm(EKAlarm(absoluteDate: next))
            }
            do { try store.save(item, commit: true); return true } catch { return false }
        }

        item.isCompleted = true
        do {
            try store.save(item, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// Computes the next occurrence after `date` for an EKRecurrenceRule.
    /// Covers the preset rules; unknown shapes fall back to a sensible default.
    private func nextOccurrence(after date: Date, rule: EKRecurrenceRule) -> Date? {
        let cal = Calendar.current
        let interval = max(rule.interval, 1)
        switch rule.frequency {
        case .daily:
            return cal.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            if let days = rule.daysOfTheWeek, !days.isEmpty {
                let allowed = Set(days.map(\.dayOfTheWeek.rawValue))
                var probe = cal.date(byAdding: .day, value: 1, to: date) ?? date
                for _ in 0..<14 {
                    let wd = cal.component(.weekday, from: probe)
                    if allowed.contains(wd) { return probe }
                    probe = cal.date(byAdding: .day, value: 1, to: probe) ?? probe
                }
                return probe
            }
            return cal.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            return cal.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return cal.date(byAdding: .year, value: interval, to: date)
        @unknown default:
            return cal.date(byAdding: .day, value: 1, to: date)
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
        priority: Int = 0,
        recurrence: RecurrencePreset = .none,
        calendarIdentifier: String? = nil,
        labels: [String] = []
    ) -> String? {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return nil }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.priority = priority
        if let calendarIdentifier,
           let target = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == calendarIdentifier }) {
            reminder.calendar = target
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }
        reminder.notes = AxisReminderNotes.encode(notes: notes, meetingInfo: meetingInfo, labels: labels)
        if let dueDate {
            var comps: Set<Calendar.Component> = [.year, .month, .day]
            if includeDueTime { comps.formUnion([.hour, .minute]) }
            reminder.dueDateComponents = Calendar.current.dateComponents(comps, from: dueDate)
            if includeDueTime {
                let alarm = EKAlarm(absoluteDate: dueDate)
                reminder.addAlarm(alarm)
            }
        }
        if let rule = recurrence.buildRule() {
            // EKReminder requires a due date for a recurrence rule to apply —
            // anchor to today midnight if the caller didn't supply one.
            if reminder.dueDateComponents == nil {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            }
            reminder.addRecurrenceRule(rule)
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
        isCompleted: Bool? = nil,
        recurrence: RecurrencePreset? = nil,
        calendarIdentifier: String? = nil,
        labels: [String]? = nil
    ) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return false }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        if let title { reminder.title = title }
        if notes != nil || meetingInfo != nil || labels != nil {
            // Preserve whichever fields weren't provided by decoding current notes first.
            let current = AxisReminderNotes.decodeAll(reminder.notes)
            reminder.notes = AxisReminderNotes.encode(
                notes: notes ?? current.notes,
                meetingInfo: meetingInfo ?? current.meetingInfo,
                labels: labels ?? current.labels
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
        if let recurrence {
            reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
            if let rule = recurrence.buildRule() {
                if reminder.dueDateComponents == nil {
                    reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                }
                reminder.addRecurrenceRule(rule)
            }
        }
        if let calendarIdentifier,
           let target = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == calendarIdentifier }),
           reminder.calendar?.calendarIdentifier != calendarIdentifier {
            reminder.calendar = target
        }
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
                calendarTitle: reminder.calendar?.title,
                calendarIdentifier: reminder.calendar?.calendarIdentifier,
                recurrenceSummary: RecurrencePreset.summary(for: reminder.recurrenceRules?.first),
                labels: AxisReminderNotes.decodeAll(reminder.notes).labels
            )
        }
    }

    /// Returns the full notes (structured: user notes + meeting info) for a reminder by id.
    func reminderDetails(id: String) -> (notes: String?, meetingInfo: String?)? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return AxisReminderNotes.decode(reminder.notes)
    }

    /// Returns the labels (#tags) stored on a reminder. Editor uses this to
    /// hydrate the Labels section without re-fetching the full notes blob.
    func reminderLabels(id: String) -> [String] {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return [] }
        return AxisReminderNotes.decodeAll(reminder.notes).labels
    }

    /// Returns the active recurrence preset for a reminder by id (for editor hydration).
    func reminderRecurrence(id: String) -> RecurrencePreset {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return .none }
        return RecurrencePreset.detect(from: reminder.recurrenceRules?.first)
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
        let calendars = calendarsForAnalysis()
        // Explicit empty selection → no events (user turned every calendar off).
        if let calendars, calendars.isEmpty { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map(mapEvent).sorted { $0.startDate < $1.startDate }
    }
}

// Reminders don't have a first-class "meeting info" field, so we keep it inside
// notes using a sentinel delimiter. This lets AI Chat, the reminder detail
// sheet, and the meeting-link detector share a single source of truth.
enum AxisReminderNotes {
    private static let marker = "--- Meeting Info ---"
    private static let tagsMarker = "--- Tags ---"

    static func encode(notes: String?, meetingInfo: String?, labels: [String] = []) -> String? {
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedInfo = meetingInfo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedLabels = labels.compactMap(normalizeLabel)
        let tagsLine = normalizedLabels.isEmpty ? "" : normalizedLabels.map { "#\($0)" }.joined(separator: " ")

        var chunks: [String] = []
        if !trimmedNotes.isEmpty { chunks.append(trimmedNotes) }
        if !trimmedInfo.isEmpty { chunks.append("\(marker)\n\(trimmedInfo)") }
        if !tagsLine.isEmpty { chunks.append("\(tagsMarker)\n\(tagsLine)") }
        if chunks.isEmpty { return nil }
        return chunks.joined(separator: "\n\n")
    }

    static func decode(_ raw: String?) -> (notes: String?, meetingInfo: String?) {
        let result = decodeAll(raw)
        return (result.notes, result.meetingInfo)
    }

    static func decodeAll(_ raw: String?) -> (notes: String?, meetingInfo: String?, labels: [String]) {
        guard let raw, !raw.isEmpty else { return (nil, nil, []) }

        // Pull labels off the tail first if present.
        var working = raw
        var labels: [String] = []
        if let tagRange = working.range(of: tagsMarker) {
            let after = String(working[tagRange.upperBound...])
            labels = after
                .components(separatedBy: .whitespacesAndNewlines)
                .compactMap(normalizeLabel)
            working = String(working[..<tagRange.lowerBound])
        }

        guard let range = working.range(of: marker) else {
            let notes = working.trimmingCharacters(in: .whitespacesAndNewlines)
            return (notes.isEmpty ? nil : notes, nil, labels)
        }
        let beforeRaw = String(working[..<range.lowerBound])
        let afterRaw = String(working[range.upperBound...])
        let notes = beforeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = afterRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (notes.isEmpty ? nil : notes, info.isEmpty ? nil : info, labels)
    }

    /// Returns a label trimmed of leading `#`, lowercased, with whitespace
    /// removed. Returns nil if empty after normalization.
    static func normalizeLabel(_ raw: String) -> String? {
        let stripped = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .replacingOccurrences(of: " ", with: "")
        return stripped.isEmpty ? nil : stripped.lowercased()
    }
}

// One-shot migration that lifts existing EATask / EAProject SwiftData rows
// into iOS Reminders so the user's existing to-dos survive the Workflow-tab
// redesign. Runs at most once per install; guarded by UserDefaults flag.
enum ReminderMigrationService {
    private static let flagKey = "axis_migrated_eatasks_v1"

    static func runIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let granted = await CalendarService.shared.requestRemindersAccess()
        guard granted else {
            print("[Migration] Reminders access not granted — deferring.")
            return
        }

        let persistence = PersistenceService.shared
        let tasks = persistence.fetchEATasks()
        let projects = persistence.fetchEAProjects()
        guard !tasks.isEmpty || !projects.isEmpty else {
            UserDefaults.standard.set(true, forKey: flagKey)
            print("[Migration] Nothing to migrate; marking complete.")
            return
        }

        var migratedTasks = 0
        for task in tasks {
            let status = task.status.lowercased()
            if status == "completed" || status == "cancelled" { continue }

            let priorityInt: Int = {
                switch task.priority.lowercased() {
                case "critical", "high": return 1
                case "medium": return 5
                case "low": return 9
                default: return 0
                }
            }()

            var parts: [String] = []
            if let desc = task.taskDescription, !desc.isEmpty { parts.append(desc) }
            if let reasoning = task.aiReasoning, !reasoning.isEmpty { parts.append("AI: \(reasoning)") }
            if !task.category.isEmpty { parts.append("Category: \(task.category.capitalized)") }
            if let minutes = task.estimatedMinutes { parts.append("Estimate: \(minutes) min") }
            let notesBlob: String? = parts.isEmpty ? nil : parts.joined(separator: "\n")

            let newId = CalendarService.shared.createReminder(
                title: task.title,
                notes: notesBlob,
                meetingInfo: nil,
                dueDate: task.deadline,
                includeDueTime: false,
                priority: priorityInt
            )
            if newId != nil { migratedTasks += 1 }
        }

        var migratedProjects = 0
        for project in projects {
            let status = project.status.lowercased()
            if status == "completed" { continue }

            let title = "[Project] \(project.title)"
            var parts: [String] = []
            if !project.category.isEmpty { parts.append("Category: \(project.category.capitalized)") }
            let notesBlob: String? = parts.isEmpty ? nil : parts.joined(separator: "\n")

            let newId = CalendarService.shared.createReminder(
                title: title,
                notes: notesBlob,
                meetingInfo: nil,
                dueDate: project.deadline,
                includeDueTime: false,
                priority: 0
            )
            if newId != nil { migratedProjects += 1 }
        }

        UserDefaults.standard.set(true, forKey: flagKey)
        print("[Migration] Migrated \(migratedTasks) tasks and \(migratedProjects) projects to iOS Reminders.")
    }
}
