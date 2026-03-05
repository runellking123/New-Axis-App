import SwiftUI

struct ExplorePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "safari.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.opacity(0.5))

                VStack(spacing: 8) {
                    Text("Explore")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your personal concierge.\nDining, events, travel — curated for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "fork.knife", title: "Restaurant Discovery", subtitle: "Yelp-powered + taste learning")
                    featureRow(icon: "ticket", title: "Event Finder", subtitle: "Ticketmaster local events")
                    featureRow(icon: "airplane", title: "Trip Planner", subtitle: "Itinerary + weather + budget")
                    featureRow(icon: "sparkles", title: "Surprise Me", subtitle: "Random curated suggestion")
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
                    Text("Explore")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
