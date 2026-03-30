import EventKit
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let greeting: String
    let events: [EventItem]

    struct EventItem {
        let title: String
        let startTime: Date
        let endTime: Date
        let calendarColor: Color
        let isAllDay: Bool

        var timeString: String {
            if isAllDay { return "All Day" }
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return fmt.string(from: startTime)
        }

        var endTimeString: String {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return fmt.string(from: endTime)
        }

        var isNow: Bool {
            let now = Date()
            return now >= startTime && now <= endTime
        }

        var isUpcoming: Bool {
            startTime > Date()
        }
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(fetchTodayEvents())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = fetchTodayEvents()
        // Refresh every 15 minutes
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func fetchTodayEvents() -> TodayEntry {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else {
            return sampleEntry()
        }

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let events = ekEvents.prefix(5).map { ev in
            TodayEntry.EventItem(
                title: ev.title ?? "Untitled",
                startTime: ev.startDate,
                endTime: ev.endDate,
                calendarColor: Color(cgColor: ev.calendar.cgColor),
                isAllDay: ev.isAllDay
            )
        }

        return TodayEntry(date: Date(), greeting: greeting(), events: events)
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private func sampleEntry() -> TodayEntry {
        TodayEntry(date: Date(), greeting: "Good Morning", events: [
            .init(title: "Leadership Meeting", startTime: Date().addingTimeInterval(3600), endTime: Date().addingTimeInterval(7200), calendarColor: .blue, isAllDay: false),
            .init(title: "SACSCOC Review", startTime: Date().addingTimeInterval(10800), endTime: Date().addingTimeInterval(14400), calendarColor: .purple, isAllDay: false),
            .init(title: "Data Analytics Workshop", startTime: Date().addingTimeInterval(18000), endTime: Date().addingTimeInterval(21600), calendarColor: .green, isAllDay: false),
        ])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayEntry
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(gold)
                    .font(.caption)
                Text("Today")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            if entry.events.isEmpty {
                Spacer()
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Enjoy your free day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                Text("\(entry.events.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(gold)
                Text("events today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let next = entry.events.first(where: { $0.isUpcoming }) ?? entry.events.first {
                    Text("Next: \(next.title)")
                        .font(.system(size: 10))
                        .lineLimit(1)
                    Text(next.timeString)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(gold)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(gold)
                    .font(.caption)
                Text("Today's Schedule")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text(entry.greeting)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text("No events scheduled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.events.prefix(4).enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.calendarColor)
                            .frame(width: 3, height: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.caption)
                                .fontWeight(event.isNow ? .bold : .regular)
                                .lineLimit(1)
                            Text(event.isAllDay ? "All Day" : "\(event.timeString) - \(event.endTimeString)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if event.isNow {
                            Text("NOW")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(gold)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TodayScheduleWidget: Widget {
    let kind = "TodayScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Schedule")
        .description("Your calendar events for today from Exchange and all calendars.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    TodayScheduleWidget()
} timeline: {
    TodayEntry(date: Date(), greeting: "Good Morning", events: [
        .init(title: "Leadership Meeting", startTime: Date().addingTimeInterval(3600), endTime: Date().addingTimeInterval(7200), calendarColor: .blue, isAllDay: false),
        .init(title: "SACSCOC Review", startTime: Date().addingTimeInterval(10800), endTime: Date().addingTimeInterval(14400), calendarColor: .purple, isAllDay: false),
    ])
}
