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
                    weatherLocationBar
                    planSummaryCard
                    if store.nextBestAction != nil { nextBestActionCard }
                    if !store.atRiskTasks.isEmpty { atRiskSection }
                    if !store.activeProjects.isEmpty { projectsScroll }
                    if store.inboxCount > 0 { inboxBanner }
                    quickStatsRow
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .refreshable {
                store.send(.refreshTapped)
            }
            .background(Color(.systemGroupedBackground))
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
                    Button { onAddTapped?() } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
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
        .padding(.top, 8)
    }

    // MARK: - Weather & Location

    private var weatherLocationBar: some View {
        GlassCard {
            HStack(spacing: 12) {
                if store.isWeatherLoaded {
                    Image(systemName: store.weatherIcon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.weatherTemp)
                            .font(.headline)
                        Text(store.weatherNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                    Text("Loading weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !store.locationName.isEmpty {
                    Text(store.locationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
