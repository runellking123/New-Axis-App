import ComposableArchitecture
import SwiftUI

struct TrendsView: View {
    @Bindable var store: StoreOf<TrendsReducer>
    @State private var selectedMetric: MetricSelection?

    struct MetricSelection: Identifiable {
        let id = UUID()
        let name: String
        let value: String
        let unit: String
        let color: Color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                windowPicker

                if store.isLoading {
                    ProgressView("Crunching the numbers...")
                        .padding(.top, 40)
                } else if let data = store.trendData {
                    // Metric cards grid
                    metricGrid(data: data)

                    // Focus trend chart
                    if data.dailyFocusMinutes.contains(where: { $0 > 0 }) {
                        trendChart(
                            title: "Focus Time",
                            icon: "timer",
                            color: .blue,
                            data: data.dailyFocusMinutes,
                            value: data.focusHours,
                            prevValue: Double(data.prevFocusMinutes),
                            currentValue: Double(data.focusMinutes)
                        )
                    }

                    // Priorities trend chart
                    if data.dailyPrioritiesCompleted.contains(where: { $0 > 0 }) {
                        trendChart(
                            title: "Priorities Completed",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            data: data.dailyPrioritiesCompleted,
                            value: "\(data.prioritiesCompleted)",
                            prevValue: Double(data.prevPrioritiesCompleted),
                            currentValue: Double(data.prioritiesCompleted)
                        )
                    }

                    // Interactions trend chart
                    if data.dailyInteractions.contains(where: { $0 > 0 }) {
                        trendChart(
                            title: "Social Interactions",
                            icon: "person.2.fill",
                            color: .purple,
                            data: data.dailyInteractions,
                            value: "\(data.interactionsLogged)",
                            prevValue: Double(data.prevInteractionsLogged),
                            currentValue: Double(data.interactionsLogged)
                        )
                    }

                    // Insights section
                    if !data.insights.isEmpty {
                        insightsSection(insights: data.insights)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.onAppear) }
        .sheet(item: $selectedMetric) { metric in
            MetricDetailView(
                metricName: metric.name,
                currentValue: metric.value,
                unit: metric.unit,
                color: metric.color
            )
        }
    }

    // MARK: - Window Picker

    private var windowPicker: some View {
        HStack(spacing: 0) {
            ForEach(TrendsReducer.State.WindowSize.allCases) { window in
                Button {
                    store.send(.windowChanged(window))
                } label: {
                    Text(window.rawValue)
                        .font(.subheadline)
                        .fontWeight(store.selectedWindow == window ? .bold : .regular)
                        .foregroundStyle(store.selectedWindow == window ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            store.selectedWindow == window
                                ? Color.axisGold
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AxisTheme.chipRadius))
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AxisTheme.buttonRadius))
    }

    // MARK: - Metric Cards

    private func metricGrid(data: TrendsReducer.State.TrendDataState) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            metricCard(
                icon: "timer",
                title: "Focus",
                value: data.focusHours,
                detail: "\(data.focusSessions) sessions",
                color: .blue,
                current: Double(data.focusMinutes),
                previous: Double(data.prevFocusMinutes)
            )

            metricCard(
                icon: "checkmark.circle.fill",
                title: "Priorities",
                value: "\(data.prioritiesCompleted)/\(data.prioritiesCreated)",
                detail: completionRateText(data.completionRate),
                color: data.completionRate >= 0.7 ? .green : .orange,
                current: Double(data.prioritiesCompleted),
                previous: Double(data.prevPrioritiesCompleted)
            )

            metricCard(
                icon: "person.2.fill",
                title: "Social",
                value: "\(data.interactionsLogged)",
                detail: "\(data.uniqueContactsReached) people",
                color: .purple,
                current: Double(data.interactionsLogged),
                previous: Double(data.prevInteractionsLogged)
            )

            metricCard(
                icon: "hands.clap.fill",
                title: "Dad Wins",
                value: "\(data.dadWinsCount)",
                detail: data.dadWinsCount > 0 ? "Keep it up" : "Log a win",
                color: Color.axisGold,
                current: Double(data.dadWinsCount),
                previous: Double(data.prevDadWinsCount)
            )

            if data.pomodorosCompleted > 0 {
                metricCard(
                    icon: "flame.fill",
                    title: "Pomodoros",
                    value: "\(data.pomodorosCompleted)",
                    detail: "\(data.focusSessions) sessions",
                    color: .red,
                    current: Double(data.pomodorosCompleted),
                    previous: 0
                )
            }

            if data.placesVisited > 0 {
                metricCard(
                    icon: "mappin.and.ellipse",
                    title: "Explored",
                    value: "\(data.placesVisited)",
                    detail: "new places",
                    color: .teal,
                    current: Double(data.placesVisited),
                    previous: 0
                )
            }
        }
    }

    private func metricCard(
        icon: String,
        title: String,
        value: String,
        detail: String,
        color: Color,
        current: Double,
        previous: Double
    ) -> some View {
        Button {
            selectedMetric = MetricSelection(name: title, value: value, unit: detail, color: color)
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(color)
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TrendIndicator(current: current, previous: previous)
                    }

                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trend Chart Card

    private func trendChart(
        title: String,
        icon: String,
        color: Color,
        data: [Double],
        value: String,
        prevValue: Double,
        currentValue: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    TrendIndicator(current: currentValue, previous: prevValue)
                }

                HStack(alignment: .bottom) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    MiniBarChartView(data: data, color: color)
                        .frame(width: 120, height: 40)
                }

                // Day labels
                HStack {
                    Spacer()
                    Text(dayRangeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dayRangeLabel: String {
        let days = store.selectedWindow.days
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return "\(formatter.string(from: start)) - \(formatter.string(from: Date()))"
    }

    // MARK: - Insights

    private func insightsSection(insights: [TrendsReducer.State.TrendDataState.InsightState]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.axisGold)
                Text("Insights")
                    .font(.headline)
            }

            ForEach(insights) { insight in
                GlassCard {
                    HStack(spacing: 10) {
                        Image(systemName: insight.icon)
                            .font(.callout)
                            .foregroundStyle(insightColor(insight.category))
                            .frame(width: 24)
                        Text(insight.message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }

    private func insightColor(_ category: String) -> Color {
        switch category {
        case "productivity": return .blue
        case "social": return .purple
        case "wellness": return .green
        case "habits": return .orange
        default: return Color.axisGold
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Color.axisGold.opacity(0.5))
            Text("No trend data yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Use AXIS for a few days and trends will appear here as your data grows.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }

    private func completionRateText(_ rate: Double) -> String {
        let pct = Int(rate * 100)
        if pct >= 80 { return "\(pct)% done" }
        if pct >= 50 { return "\(pct)% done" }
        return "\(pct)% — room to grow"
    }
}
