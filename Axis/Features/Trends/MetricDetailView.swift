import SwiftUI

struct MetricDetailView: View {
    let metricName: String
    let currentValue: String
    let unit: String
    let color: Color
    var history: [Double] = []
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

                    // 7-day trend
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("7-Day Trend")
                                .font(.headline)
                            AxisTrendChart(values: history, tint: color)
                                .frame(height: 160)
                        }
                    }

                    // Period comparison
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Period Comparison")
                                .font(.headline)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Now")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(currentValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("7-Day Avg")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(historyAverage)
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

    private var historyAverage: String {
        let valid = history.filter { $0 > 0 }
        guard !valid.isEmpty else { return "--" }
        return String(format: "%.1f", valid.reduce(0, +) / Double(valid.count))
    }
}

#Preview {
    MetricDetailView(
        metricName: "Energy",
        currentValue: "7.2",
        unit: "avg / 10",
        color: .green,
        history: [5, 6, 4, 7, 8, 6, 7]
    )
}
