import SwiftUI
import WidgetKit

struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = QuickActionsEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct QuickActionsWidgetView: View {
    let entry: QuickActionsEntry
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(gold)
                Text("AXIS")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text("Quick Actions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                actionButton(icon: "bubble.left.fill", label: "Chat", destination: "axis://chat")
                actionButton(icon: "fork.knife", label: "Meal", destination: "axis://meal")
                actionButton(icon: "note.text", label: "Note", destination: "axis://note")
                actionButton(icon: "mic.fill", label: "Memo", destination: "axis://memo")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func actionButton(icon: String, label: String, destination: String) -> some View {
        Link(destination: URL(string: destination)!) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(gold)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct QuickActionsWidget: Widget {
    let kind = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Jump straight into Chat, Meals, Notes, or Voice Memos.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: Date())
}
