import ComposableArchitecture
import SwiftUI

struct EADashboardView: View {
    @Bindable var store: StoreOf<EADashboardReducer>
    var onNavigateToPlanner: (() -> Void)?
    var onNavigateToTasks: (() -> Void)?
    var onNavigateToProjects: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onAddTapped: (() -> Void)?
    var onCompletedTasksTapped: (() -> Void)?
    var onMeetingsTapped: (() -> Void)?
    var onDeepWorkTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    quickAddField
                    weatherLocationBar
                    planSummaryCard
                    if store.nextBestAction != nil { nextBestActionCard }
                    if !store.isFocusMode {
                        if !store.atRiskTasks.isEmpty { atRiskSection }
                        if !store.activeProjects.isEmpty { projectsScroll }
                        if store.inboxCount > 0 { inboxBanner }
                        quickStatsRow
                        if !store.upcomingDeadlines.isEmpty { deadlinesSection }
                        if !store.recentChatSummary.isEmpty { recentChatSection }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .refreshable {
                store.send(.refreshTapped)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Executive Assistant")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onSettingsTapped?() } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { store.send(.toggleFocusMode) } label: {
                            Image(systemName: store.isFocusMode ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(store.isFocusMode ? .orange : Color.axisGold)
                        }
                        Button { onAddTapped?() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisGold)
                        }
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentGreeting)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(store.userName.isEmpty ? "Commander" : store.userName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.axisGold)
                }
                Spacer()
                if store.isEnergyLoaded {
                    VStack(spacing: 2) {
                        Text("\(store.energyScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(store.energyScore >= 7 ? .green : store.energyScore >= 4 ? .orange : .red)
                        Text("Energy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if store.streakDays > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("\(store.streakDays) day streak")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.15))
                .clipShape(.capsule)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Quick Add Task

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.axisGold)
            TextField("Quick add a task...", text: $store.quickAddText.sending(\.quickAddTextChanged))
                .font(.subheadline)
                .onSubmit { store.send(.quickAddSubmit) }
            if !store.quickAddText.isEmpty {
                Button { store.send(.quickAddSubmit) } label: {
                    Text("Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.axisGold)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Weather & Location

    private var weatherLocationBar: some View {
        GlassCard {
            if store.isWeatherLoaded {
                VStack(alignment: .leading, spacing: 12) {
                    // Top row: icon, temp, condition, location
                    HStack(spacing: 12) {
                        Image(systemName: store.weatherIcon)
                            .font(.system(size: 36))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.multicolor)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(store.weatherTemp)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                if !store.weatherCondition.isEmpty {
                                    Text(store.weatherCondition)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !store.locationName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.axisGold)
                                    Text(store.locationName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    // Detail row: feels like, humidity
                    if !store.weatherFeelsLike.isEmpty {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.medium")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("Feels \(store.weatherFeelsLike)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !store.weatherHumidity.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "humidity.fill")
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                    Text("Humidity \(store.weatherHumidity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }

                    // Actionable note
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(Color.axisGold)
                        Text(store.weatherNote)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Plan Summary

    private var planSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.axisGold)
                    Text("Today's Plan")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                    Spacer()
                    Button { onNavigateToPlanner?() } label: {
                        Text("View All")
                            .font(.caption)
                            .foregroundStyle(Color.axisGold)
                    }
                }

                if store.isPlanLoaded {
                    Text(store.planSummary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    ForEach(store.planTimeBlocks.prefix(3)) { block in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(blockColor(block.blockType))
                                .frame(width: 8, height: 8)
                            Text(block.startTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(block.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                } else {
                    Text("Generating your daily plan...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .shimmer()
                }
            }
        }
    }

    // MARK: - Next Best Action

    private var nextBestActionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Next Best Action")
                        .font(.headline)
                        .foregroundStyle(.purple)
                }
                if let action = store.nextBestAction {
                    Text(action.taskTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(action.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - At-Risk Tasks

    private var atRiskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("At Risk")
                .font(.headline)
                .foregroundStyle(.red)

            ForEach(store.atRiskTasks) { task in
                GlassCard {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Due \(task.deadline, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Schedule") {
                            store.send(.scheduleAtRiskTask(task.id))
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
        }
    }

    // MARK: - Active Projects

    private var projectsScroll: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Projects")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.activeProjects) { project in
                        Button {
                            onNavigateToProjects?()
                        } label: {
                            GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(project.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Spacer()
                                }

                                ProgressView(value: project.progress)
                                    .tint(Color.axisGold)

                                HStack {
                                    Text("\(Int(project.progress * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if let days = project.daysToDeadline {
                                        Text("\(days)d left")
                                            .font(.caption2)
                                            .foregroundStyle(days < 3 ? .red : .secondary)
                                    }
                                }
                            }
                        }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 180)
                    }
                }
            }
        }
    }

    // MARK: - Inbox Banner

    private var inboxBanner: some View {
        Button { onNavigateToTasks?() } label: {
            GlassCard {
                HStack {
                    Image(systemName: "tray.fill")
                        .foregroundStyle(.orange)
                    Text("\(store.inboxCount) unreviewed item\(store.inboxCount == 1 ? "" : "s") in inbox")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "checkmark.circle.fill", value: "\(store.tasksCompletedToday)", label: "Done", color: .green, action: onCompletedTasksTapped)
            statCard(icon: "calendar", value: "\(store.meetingsRemaining)", label: "Meetings", color: .purple, action: onMeetingsTapped)
            statCard(icon: "brain.head.profile", value: String(format: "%.1fh", store.deepWorkHoursToday), label: "Deep Work", color: .blue, action: onDeepWorkTapped)
        }
    }

    // MARK: - Upcoming Deadlines

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.red)
                Text("Upcoming Deadlines")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            ForEach(store.upcomingDeadlines) { deadline in
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deadline.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(deadline.category.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(deadline.daysLeft == 0 ? "Today" : deadline.daysLeft == 1 ? "Tomorrow" : "\(deadline.daysLeft)d left")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(deadline.daysLeft <= 1 ? .red : deadline.daysLeft <= 3 ? .orange : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Recent AI Chat

    private var recentChatSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .foregroundStyle(Color.axisGold)
                    Text("Recent AI Chat")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                }
                Text(store.recentChatSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            GlassCard {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Text(value)
                        .font(.headline)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    private func blockColor(_ type: String) -> Color {
        switch type {
        case "meeting": return .purple
        case "focusBlock": return .blue
        case "break": return .green
        case "task": return Color.axisGold
        default: return .gray
        }
    }
}


#Preview {
    EADashboardView(
        store: Store(initialState: EADashboardReducer.State()) {
            EADashboardReducer()
        }
    )
}
