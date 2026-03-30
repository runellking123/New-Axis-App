import SwiftUI
import WidgetKit

struct DeadlinesEntry: TimelineEntry {
    let date: Date
    let deadlines: [DeadlineItem]

    struct DeadlineItem {
        let title: String
        let deadline: Date
        let priority: String
        let isUrgent: Bool

        var timeRemaining: String {
            let interval = deadline.timeIntervalSince(Date())
            if interval < 0 { return "Overdue" }
            let hours = Int(interval / 3600)
            if hours < 24 { return "\(hours)h left" }
            let days = hours / 24
            return "\(days)d left"
        }

        var priorityColor: Color {
            switch priority {
            case "critical": return .red
            case "high": return .orange
            default: return .blue
            }
        }
    }
}

struct DeadlinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeadlinesEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (DeadlinesEntry) -> Void) {
        completion(sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeadlinesEntry>) -> Void) {
        // Read from shared UserDefaults if App Group is set up, otherwise show sample
        let entry = readDeadlines() ?? sampleEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func readDeadlines() -> DeadlinesEntry? {
        guard let defaults = UserDefaults(suiteName: "group.com.runellking.axis"),
              let data = defaults.data(forKey: "widget_deadlines"),
              let items = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return nil
        }
        let deadlines = items.compactMap { dict -> DeadlinesEntry.DeadlineItem? in
            guard let title = dict["title"],
                  let deadlineStr = dict["deadline"],
                  let deadline = ISO8601DateFormatter().date(from: deadlineStr) else { return nil }
            let priority = dict["priority"] ?? "medium"
            let hours = deadline.timeIntervalSince(Date()) / 3600
            return DeadlinesEntry.DeadlineItem(title: title, deadline: deadline, priority: priority, isUrgent: hours < 24)
        }
        return DeadlinesEntry(date: Date(), deadlines: deadlines)
    }

    private func sampleEntry() -> DeadlinesEntry {
        DeadlinesEntry(date: Date(), deadlines: [
            .init(title: "IPEDS report submission", deadline: Date().addingTimeInterval(18 * 3600), priority: "critical", isUrgent: true),
            .init(title: "Review retention data", deadline: Date().addingTimeInterval(48 * 3600), priority: "high", isUrgent: false),
            .init(title: "Board presentation prep", deadline: Date().addingTimeInterval(65 * 3600), priority: "high", isUrgent: false),
        ])
    }
}

struct DeadlinesWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DeadlinesEntry
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Deadlines")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            if entry.deadlines.isEmpty {
                Spacer()
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All clear")
                        .font(.caption)
                }
                Spacer()
            } else {
                let urgent = entry.deadlines.filter(\.isUrgent).count
                Text("\(entry.deadlines.count)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(urgent > 0 ? .red : gold)

                Text(urgent > 0 ? "\(urgent) urgent" : "due soon")
                    .font(.caption2)
                    .foregroundStyle(urgent > 0 ? .red : .secondary)

                Spacer()

                if let first = entry.deadlines.first {
                    Text(first.title)
                        .font(.system(size: 10))
                        .lineLimit(1)
                    Text(first.timeRemaining)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(first.isUrgent ? .red : .orange)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Upcoming Deadlines")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                let urgent = entry.deadlines.filter(\.isUrgent).count
                if urgent > 0 {
                    Text("\(urgent) urgent")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                }
            }

            if entry.deadlines.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("No upcoming deadlines. You're all caught up!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(entry.deadlines.prefix(3).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.priorityColor)
                            .frame(width: 6, height: 6)

                        Text(item.title)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text(item.timeRemaining)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(item.isUrgent ? .red : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.isUrgent ? Color.red.opacity(0.15) : Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct DeadlinesWidget: Widget {
    let kind = "DeadlinesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeadlinesProvider()) { entry in
            DeadlinesWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Deadlines")
        .description("Tasks due within 72 hours with countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    DeadlinesWidget()
} timeline: {
    DeadlinesEntry(date: Date(), deadlines: [
        .init(title: "IPEDS report", deadline: Date().addingTimeInterval(18 * 3600), priority: "critical", isUrgent: true),
        .init(title: "Retention data review", deadline: Date().addingTimeInterval(48 * 3600), priority: "high", isUrgent: false),
    ])
}
