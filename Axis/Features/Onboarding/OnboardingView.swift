import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var userName = "Runell"

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("bolt.fill", "Welcome to AXIS", "Your personal command center.\nOne app for work, family, and life.", Color.axisGold),
        ("building.columns.fill", "Work Suite", "Dual workspaces, project boards,\nand a focus timer to get it done.", Color.axisGold),
        ("house.fill", "Family HQ", "Family calendar, meal planning,\nand a Dad Wins journal.", .blue),
        ("person.2.fill", "Social Circle", "Never lose touch. Track check-ins,\nbirthdays, and relationships.", .purple),
        ("safari.fill", "Explore", "Your personal concierge.\nDining, events, and travel — curated.", .orange),
        ("heart.fill", "Balance", "Guard your wellbeing.\nEnergy, sleep, stress — all tracked.", .green),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: page.icon)
                            .font(.system(size: 70))
                            .foregroundStyle(page.color)
                            .symbolEffect(.pulse, options: .repeating)

                        VStack(spacing: 12) {
                            Text(page.title)
                                .font(.system(size: 26, weight: .bold, design: .serif))

                            Text(page.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        // Name input on first page
                        if index == 0 {
                            VStack(spacing: 8) {
                                Text("What should we call you?")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("Your name", text: $userName)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 16)
                        }

                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom section
            VStack(spacing: 16) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.axisGold : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 7, height: index == currentPage ? 10 : 7)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }

                // Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Let's Go")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.axisGold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AxisTheme.buttonRadius))
                }
                .padding(.horizontal, 24)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func completeOnboarding() {
        let persistence = PersistenceService.shared
        let profile = persistence.getOrCreateProfile()
        profile.name = userName
        profile.onboardingComplete = true
        persistence.updateUserProfile()
        HapticService.celebration()
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
