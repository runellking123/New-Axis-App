import SwiftUI

struct MetricDetailView: View {
    let metricName: String
    let currentValue: String
    let unit: String
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current value hero
                    VStack(spacing: 8) {
                        Text(currentValue)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(color)
                        Text(unit)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Placeholder chart area
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("7-Day Trend")
                                .font(.headline)

                            // Simple bar chart placeholder
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<7, id: \.self) { day in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color.opacity(day == 6 ? 1.0 : 0.4))
                                            .frame(width: 30, height: CGFloat.random(in: 30...120))
                                        Text(dayLabel(daysAgo: 6 - day))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                        }
                    }

                    // Period comparison
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Period Comparison")
                                .font(.headline)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("This Week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(currentValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Last Week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("--")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(metricName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func dayLabel(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    MetricDetailView(metricName: "Sleep", currentValue: "7.2", unit: "hours", color: .purple)
}
