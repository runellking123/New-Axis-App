import SwiftUI

struct StepsDetailView: View {
    let stepsToday: Int
    let stepsGoal: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 16)
                            .frame(width: 160, height: 160)
                        Circle()
                            .trim(from: 0, to: min(Double(stepsToday) / Double(stepsGoal), 1.0))
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text("\(stepsToday)")
                                .font(.system(size: 28, weight: .bold))
                            Text("of \(stepsGoal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Stats
                    HStack(spacing: 16) {
                        statItem(
                            icon: "flame.fill",
                            value: "\(estimatedCalories)",
                            label: "Active Cal",
                            color: .orange
                        )
                        statItem(
                            icon: "figure.walk",
                            value: String(format: "%.1f", estimatedMiles),
                            label: "Miles",
                            color: .green
                        )
                        statItem(
                            icon: "percent",
                            value: "\(progressPercent)%",
                            label: "Goal",
                            color: progressColor
                        )
                    }

                    // Encouragement
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(encouragement)
                                .font(.headline)
                            Text(encouragementDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        GlassCard {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var progressColor: Color {
        let pct = Double(stepsToday) / Double(stepsGoal)
        if pct >= 1.0 { return .green }
        if pct >= 0.5 { return .orange }
        return .red
    }

    private var progressPercent: Int {
        Int(min(Double(stepsToday) / Double(stepsGoal) * 100, 100))
    }

    private var estimatedCalories: Int {
        stepsToday / 20 // rough estimate
    }

    private var estimatedMiles: Double {
        Double(stepsToday) / 2000.0 // rough estimate
    }

    private var encouragement: String {
        let remaining = stepsGoal - stepsToday
        if remaining <= 0 { return "Goal reached!" }
        if remaining < 2000 { return "Almost there!" }
        return "Keep moving!"
    }

    private var encouragementDetail: String {
        let remaining = stepsGoal - stepsToday
        if remaining <= 0 { return "You've hit your daily step goal. Great work!" }
        return "\(remaining) steps to go. A \(remaining / 100)-minute walk should do it."
    }
}
