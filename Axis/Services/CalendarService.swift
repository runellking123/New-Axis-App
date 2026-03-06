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
}
