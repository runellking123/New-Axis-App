import SwiftUI
import WidgetKit

struct EnergyEntry: TimelineEntry {
    let date: Date
    let energyScore: Int
    let sleepHours: Double
    let stepsToday: Int
    let stepsGoal: Int
}

struct EnergyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EnergyEntry {
        EnergyEntry(date: Date(), energyScore: 7, sleepHours: 7.2, stepsToday: 6500, stepsGoal: 10000)
    }

    func getSnapshot(in context: Context, completion: @escaping (EnergyEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EnergyEntry>) -> Void) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct EnergyWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: EnergyEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(energyColor)
                Text("Energy")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text(energyLabel)
                    .font(.caption2)
                    .foregroundStyle(energyColor)
            }

            // Energy bar
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level <= entry.energyScore ? barColor(level) : Color(.systemGray4))
                        .frame(height: 20)
                }
            }

            HStack {
                // Sleep
                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 9))
                    Text(String(format: "%.1fh", entry.sleepHours))
                        .font(.system(size: 10))
                }
                .foregroundStyle(entry.sleepHours >= 7 ? .blue : .orange)

                Spacer()

                // Steps
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9))
                    Text("\(entry.stepsToday)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Double(entry.stepsToday) / Double(entry.stepsGoal) >= 0.7 ? .green : .orange)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var energyColor: Color {
        switch entry.energyScore {
        case 8...10: return .green
        case 5...7: return .blue
        case 3...4: return .orange
        default: return .red
        }
    }

    private var energyLabel: String {
        switch entry.energyScore {
        case 8...10: return "Energized"
        case 5...7: return "Steady"
        case 3...4: return "Low"
        default: return "Depleted"
        }
    }

    private func barColor(_ level: Int) -> Color {
        if level <= 3 { return .red }
        if level <= 5 { return .orange }
        if level <= 7 { return .blue }
        return .green
    }
}

struct EnergyWidget: Widget {
    let kind = "EnergyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EnergyProvider()) { entry in
            EnergyWidgetView(entry: entry)
        }
        .configurationDisplayName("Energy Level")
        .description("Track your energy, sleep, and steps.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    EnergyWidget()
} timeline: {
    EnergyEntry(date: Date(), energyScore: 7, sleepHours: 7.2, stepsToday: 6500, stepsGoal: 10000)
}
