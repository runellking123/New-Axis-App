import SwiftUI

struct EnergyScoreView: View {
    let score: Int

    private var color: Color {
        switch score {
        case 8...10: return .green
        case 5...7: return .yellow
        default: return .red
        }
    }

    private var label: String {
        switch score {
        case 8...10: return "High"
        case 5...7: return "Moderate"
        default: return "Low"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 10.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}
