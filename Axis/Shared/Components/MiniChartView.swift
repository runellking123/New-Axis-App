import SwiftUI

// MARK: - Sparkline

struct SparklineView: View {
    let data: [Double]
    var color: Color = .axisGold
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            if data.count >= 2, let minVal = data.min(), let maxVal = data.max() {
                let range = maxVal - minVal
                let safeRange = range == 0 ? 1.0 : range
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(data.count - 1)
                        let y = geo.size.height * (1 - CGFloat((value - minVal) / safeRange))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Mini Bar Chart

struct MiniBarChartView: View {
    let data: [Double]
    var color: Color = .axisGold
    var barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            if !data.isEmpty, let maxVal = data.max(), maxVal > 0 {
                HStack(spacing: barSpacing) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(value > 0 ? 1.0 : 0.2))
                            .frame(height: max(2, geo.size.height * CGFloat(value / maxVal)))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Trend Direction Indicator

struct TrendIndicator: View {
    let current: Double
    let previous: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: arrowIcon)
                .font(.caption2)
            Text(changeText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(changeColor)
    }

    private var percentChange: Double {
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return ((current - previous) / previous) * 100
    }

    private var arrowIcon: String {
        if percentChange > 5 { return "arrow.up.right" }
        if percentChange < -5 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var changeText: String {
        let absChange = abs(percentChange)
        if absChange < 1 { return "same" }
        return String(format: "%.0f%%", absChange)
    }

    private var changeColor: Color {
        if percentChange > 5 { return .green }
        if percentChange < -5 { return .red }
        return .secondary
    }
}

// MARK: - Habit Heatmap (7-day row)

struct HabitWeekRow: View {
    let completions: [Bool] // 7 bools for Mon-Sun
    var color: Color = .green

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(completions.prefix(7).enumerated()), id: \.offset) { index, completed in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(completed ? color : color.opacity(0.15))
                        .frame(width: 20, height: 20)
                    Text(dayLabels[index])
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Sparkline") {
    SparklineView(data: [3, 5, 2, 8, 4, 7, 6])
        .frame(height: 40)
        .padding()
}

#Preview("Trend Indicator") {
    VStack(spacing: 12) {
        TrendIndicator(current: 120, previous: 100)
        TrendIndicator(current: 80, previous: 100)
    }
    .padding()
}
