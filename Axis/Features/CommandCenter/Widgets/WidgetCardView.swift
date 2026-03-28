import SwiftUI

struct WidgetCardView: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
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
                }

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    HStack {
        WidgetCardView(icon: "cloud.fill", title: "Weather", value: "72°", subtitle: "Partly cloudy", color: .blue)
        WidgetCardView(icon: "bolt.fill", title: "Energy", value: "8/10", subtitle: "Deep work ready", color: .green)
    }
    .padding()
}
