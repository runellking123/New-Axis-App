import SwiftUI

struct SleepDetailView: View {
    let sleepHours: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Sleep ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 16)
                            .frame(width: 160, height: 160)
                        Circle()
                            .trim(from: 0, to: min(sleepHours / 8.0, 1.0))
                            .stroke(sleepColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", sleepHours))
                                .font(.system(size: 36, weight: .bold))
                            Text("hours")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Goal comparison
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Goal: 8 hours")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(sleepHours >= 7 ? "Well rested" : sleepHours >= 5 ? "Could be better" : "Sleep deprived")
                                    .font(.headline)
                                    .foregroundStyle(sleepColor)
                            }
                            Spacer()
                            Text(String(format: "%+.1f hrs", sleepHours - 8))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(sleepHours >= 7 ? .green : .red)
                        }
                    }

                    // Tips
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sleep Tips")
                                .font(.headline)
                            ForEach(sleepTips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "moon.fill")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                    Text(tip)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var sleepColor: Color {
        if sleepHours >= 7 { return .green }
        if sleepHours >= 5 { return .orange }
        return .red
    }

    private var sleepTips: [String] {
        var tips = [String]()
        if sleepHours < 7 {
            tips.append("Aim for 7-8 hours tonight — set a bedtime alarm")
            tips.append("Avoid screens 30 minutes before bed")
        }
        if sleepHours < 5 {
            tips.append("Consider a 20-minute power nap today")
        }
        tips.append("Keep your bedroom cool (65-68F)")
        tips.append("Consistent wake time improves sleep quality")
        return tips
    }
}
