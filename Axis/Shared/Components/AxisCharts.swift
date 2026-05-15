import SwiftUI
import Charts

// MARK: - Ring Chart
// Circular progress ring with an optional center label. Used for energy,
// completion rates, and any 0...1 progress value. Animates on appear.

struct AxisRingChart<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = .axisAccent
    var trackColor: Color = Color.primary.opacity(0.1)
    @ViewBuilder var center: () -> Center

    @State private var animatedProgress: Double = 0

    private var clamped: Double { max(0, min(1, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0.65), tint]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { animatedProgress = clamped }
        }
        .onChange(of: clamped) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) { animatedProgress = newValue }
        }
    }
}

extension AxisRingChart where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 8, tint: Color = .axisAccent,
         trackColor: Color = Color.primary.opacity(0.1)) {
        self.init(progress: progress, lineWidth: lineWidth, tint: tint, trackColor: trackColor) {
            EmptyView()
        }
    }
}

// MARK: - Sparkline
// Compact, axis-free trend line for inline use inside stat tiles and rows.

struct AxisSparkline: View {
    let values: [Double]
    var tint: Color = .axisAccent
    var showArea: Bool = true

    var body: some View {
        if values.count >= 2 {
            Chart(Array(values.enumerated()), id: \.offset) { index, value in
                if showArea {
                    AreaMark(x: .value("Index", index), y: .value("Value", value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.32), tint.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                LineMark(x: .value("Index", index), y: .value("Value", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(tint.opacity(0.12))
        }
    }
}

// MARK: - Trend Chart
// Larger time-series chart with a soft gradient fill and a light Y grid.
// Use for Trends / Balance / Budget detail screens.

struct AxisTrendChart: View {
    let values: [Double]
    var labels: [String]? = nil
    var tint: Color = .axisAccent
    var showYAxis: Bool = true

    var body: some View {
        if values.count >= 2 {
            Chart(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Point", labels?[safe: index] ?? "\(index)"),
                    y: .value("Value", value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Point", labels?[safe: index] ?? "\(index)"),
                    y: .value("Value", value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis(labels == nil ? .hidden : .automatic)
            .chartYAxis {
                if showYAxis {
                    AxisMarks(position: .leading)
                }
            }
            .chartLegend(.hidden)
        } else {
            AxisEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: "Not enough data yet",
                message: "Check back once there's more history to chart."
            )
        }
    }
}

// MARK: - Bar Chart
// Labeled bar comparison. Use for category breakdowns and week-over-week.

struct AxisBarChart: View {
    struct Bar: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: Double
        var tint: Color = .axisAccent
    }

    let bars: [Bar]
    var showValues: Bool = true

    var body: some View {
        if bars.isEmpty {
            AxisEmptyState(
                icon: "chart.bar",
                title: "Nothing to compare yet",
                message: "Data will appear here as you log activity."
            )
        } else {
            Chart(bars) { bar in
                BarMark(
                    x: .value("Category", bar.label),
                    y: .value("Value", bar.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [bar.tint, bar.tint.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .annotation(position: .top) {
                    if showValues {
                        Text(bar.value.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        }
    }
}

// MARK: - Stat Tile
// Composed metric card: icon + value + label, with an optional inline
// sparkline. The workhorse cell for dashboards and detail screens.

struct AxisStatTile: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = .axisAccent
    var trend: [Double]? = nil
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack(spacing: AxisSpacing.sm) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        tint.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: AxisRadius.chip, style: .continuous)
                    )
                Spacer(minLength: 0)
                if let trend, trend.count >= 2 {
                    AxisSparkline(values: trend, tint: tint)
                        .frame(width: 54, height: 26)
                }
            }
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(AxisSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
        .shadow(color: AxisTheme.cardShadow, radius: 4, y: 1)
    }
}

// MARK: - Safe collection subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Ring") {
    AxisRingChart(progress: 0.72, lineWidth: 10, tint: .green) {
        Text("72")
            .font(.system(.title3, design: .rounded).weight(.bold))
    }
    .frame(width: 90, height: 90)
    .padding()
}

#Preview("Sparkline") {
    AxisSparkline(values: [3, 5, 2, 8, 4, 7, 6, 9])
        .frame(width: 80, height: 32)
        .padding()
}

#Preview("Trend") {
    AxisTrendChart(values: [12, 18, 9, 24, 21, 30, 27])
        .frame(height: 180)
        .padding()
}

#Preview("Bars") {
    AxisBarChart(bars: [
        .init(label: "Mon", value: 4),
        .init(label: "Tue", value: 7),
        .init(label: "Wed", value: 3, tint: .orange),
        .init(label: "Thu", value: 9),
    ])
    .frame(height: 180)
    .padding()
}

#Preview("Stat Tile") {
    AxisStatTile(
        icon: "flame.fill",
        value: "1,240",
        label: "Focus minutes",
        tint: .orange,
        trend: [3, 5, 2, 8, 4, 7, 6],
        caption: "+12% vs last week"
    )
    .frame(width: 180)
    .padding()
}
