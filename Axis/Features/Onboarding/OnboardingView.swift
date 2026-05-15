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
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageContent(index: index, page: page)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: currentPage)

            bottomSection
        }
        .background(AxisTheme.darkGradient.ignoresSafeArea())
    }

    // MARK: - Page

    private func pageContent(
        index: Int,
        page: (icon: String, title: String, subtitle: String, color: Color)
    ) -> some View {
        VStack(spacing: AxisSpacing.xl) {
            Spacer()

            // Glowing icon badge
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.18))
                    .frame(width: 170, height: 170)
                    .blur(radius: 14)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.color.opacity(0.35), page.color.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(Circle().strokeBorder(page.color.opacity(0.5), lineWidth: 1))
                Image(systemName: page.icon)
                    .font(.system(size: 58))
                    .foregroundStyle(page.color)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .axisAppear()

            VStack(spacing: AxisSpacing.md) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .axisAppear(delay: 0.1)

            // Name input on first page
            if index == 0 {
                VStack(spacing: AxisSpacing.sm) {
                    Text("What should we call you?")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("Your name", text: $userName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, AxisSpacing.md)
                        .padding(.horizontal, AxisSpacing.xl)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                                .strokeBorder(Color.axisGold.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 48)
                }
                .padding(.top, AxisSpacing.lg)
                .axisAppear(delay: 0.2)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AxisSpacing.xl)
    }

    // MARK: - Bottom

    private var bottomSection: some View {
        VStack(spacing: AxisSpacing.lg) {
            // Page indicators
            HStack(spacing: AxisSpacing.sm) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.axisGold : Color.white.opacity(0.25))
                        .frame(width: index == currentPage ? 22 : 7, height: 7)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Continue" : "Let's Go")
            }
            .buttonStyle(.axisPrimary)
            .padding(.horizontal, AxisSpacing.xl)

            if currentPage < pages.count - 1 {
                Button("Skip") { completeOnboarding() }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                // Keep the bottom section height stable on the last page.
                Color.clear.frame(height: 16)
            }
        }
        .padding(.bottom, 40)
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
