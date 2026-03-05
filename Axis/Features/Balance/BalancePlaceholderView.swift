import SwiftUI

struct BalancePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green.opacity(0.5))

                VStack(spacing: 8) {
                    Text("Balance")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your wellbeing guardian.\nSleep, energy, and work-life harmony.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "bolt.fill", title: "Energy Score", subtitle: "HealthKit sleep + activity data")
                    featureRow(icon: "chart.pie", title: "Balance Meter", subtitle: "Time allocation across modules")
                    featureRow(icon: "doc.text", title: "Weekly Report", subtitle: "AI-generated week summary")
                    featureRow(icon: "exclamationmark.bubble", title: "Stress Detection", subtitle: "Calendar overload alerts")
                    featureRow(icon: "bed.double", title: "Recovery Windows", subtitle: "Smart rest suggestions")
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Coming in Phase 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Balance")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
