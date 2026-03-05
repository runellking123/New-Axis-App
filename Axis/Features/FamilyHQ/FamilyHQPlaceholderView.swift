import SwiftUI

struct FamilyHQPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.opacity(0.5))

                VStack(spacing: 8) {
                    Text("Family HQ")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Shared family space with Morgan.\nCalendar, meals, and moments.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "calendar", title: "Family Calendar", subtitle: "Shared with Morgan via CloudKit")
                    featureRow(icon: "fork.knife", title: "Meal Planner", subtitle: "Weekly grid + grocery lists")
                    featureRow(icon: "figure.and.child.holdinghands", title: "Kid Tracker", subtitle: "School, activities, milestones")
                    featureRow(icon: "mappin.and.ellipse", title: "Outing Planner", subtitle: "Weather-aware family activities")
                    featureRow(icon: "heart.fill", title: "Dad Wins", subtitle: "Photo journal of special moments")
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Coming in Phase 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Family HQ")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
