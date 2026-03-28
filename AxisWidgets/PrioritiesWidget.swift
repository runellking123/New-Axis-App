import SwiftUI
import WidgetKit

struct PrioritiesEntry: TimelineEntry {
    let date: Date
    let priorities: [PriorityData]
    let completedCount: Int
    let totalCount: Int

    struct PriorityData {
        let title: String
        let sourceIcon: String
        let isCompleted: Bool
    }
}

struct PrioritiesProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrioritiesEntry {
        PrioritiesEntry(
            date: Date(),
            priorities: [
                .init(title: "Review sprint tasks", sourceIcon: "building.columns.fill", isCompleted: false),
                .init(title: "Pick up groceries", sourceIcon: "house.fill", isCompleted: true),
                .init(title: "Call Mom", sourceIcon: "person.2.fill", isCompleted: false),
            ],
            completedCount: 1,
            totalCount: 3
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrioritiesEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrioritiesEntry>) -> Void) {
        // In a real implementation, read from shared UserDefaults (App Group)
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct PrioritiesWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrioritiesEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Priorities")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text("\(entry.totalCount - entry.completedCount)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.13))

            Text("remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                        .frame(width: entry.totalCount > 0 ? geo.size.width * Double(entry.completedCount) / Double(entry.totalCount) : 0)
                }
            }
            .frame(height: 6)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.13))
                Text("AXIS Priorities")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text("\(entry.completedCount)/\(entry.totalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(entry.priorities.prefix(3).enumerated()), id: \.offset) { _, priority in
                HStack(spacing: 8) {
                    Image(systemName: priority.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(priority.isCompleted ? .green : .secondary)

                    Image(systemName: priority.sourceIcon)
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.13))

                    Text(priority.title)
                        .font(.caption)
                        .lineLimit(1)
                        .strikethrough(priority.isCompleted)
                        .foregroundStyle(priority.isCompleted ? .secondary : .primary)

                    Spacer()
                }
            }

            if entry.priorities.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All clear! No priorities.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PrioritiesWidget: Widget {
    let kind = "PrioritiesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrioritiesProvider()) { entry in
            PrioritiesWidgetView(entry: entry)
        }
        .configurationDisplayName("Priorities")
        .description("See your top priorities at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    PrioritiesWidget()
} timeline: {
    PrioritiesEntry(
        date: Date(),
        priorities: [
            .init(title: "Review sprint tasks", sourceIcon: "building.columns.fill", isCompleted: false),
            .init(title: "Pick up groceries", sourceIcon: "house.fill", isCompleted: true),
        ],
        completedCount: 1,
        totalCount: 2
    )
}
