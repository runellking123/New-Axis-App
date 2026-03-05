import SwiftUI

struct SocialCirclePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple.opacity(0.5))

                VStack(spacing: 8) {
                    Text("Social Circle")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your personal CRM.\nNever lose touch with people who matter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "person.crop.circle", title: "Contact Cards", subtitle: "Relationship tiers & notes")
                    featureRow(icon: "clock.arrow.circlepath", title: "Check-in Cadence", subtitle: "Never forget to reach out")
                    featureRow(icon: "gift", title: "Birthday Tracker", subtitle: "Proactive gift suggestions")
                    featureRow(icon: "message", title: "SMS Nudges", subtitle: "Twilio-powered outreach")
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
                    Text("Social Circle")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.purple)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
