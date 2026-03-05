import ComposableArchitecture
import SwiftUI

struct CommandCenterView: View {
    @Bindable var store: StoreOf<CommandCenterReducer>
    var onSettingsTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with greeting and mode switcher
                    headerSection

                    // Day Brief card
                    dayBriefCard

                    // Widget grid
                    widgetGrid

                    // Priorities list
                    prioritiesSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AXIS")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onSettingsTapped?()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.toggleAddPriority)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisGold)
                        }
                        Button {
                            store.send(.refreshTapped)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.axisGold)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddPriority },
                set: { _ in store.send(.toggleAddPriority) }
            )) {
                addPrioritySheet
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentGreeting)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Runell")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.axisGold)
                }
                Spacer()

                // Energy Score
                EnergyScoreView(score: store.energyScore)
            }

            // Context Mode Switcher
            ContextModeSwitcherView(
                selectedMode: store.contextMode,
                onModeChanged: { mode in
                    store.send(.contextModeChanged(mode))
                }
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Day Brief

    private var dayBriefCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.axisGold)
                    Text("Day Brief")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                    Spacer()
                    if store.isLoadingBrief {
                        ProgressView()
                            .tint(Color.axisGold)
                    }
                }

                if store.isLoadingBrief {
                    Text("Synthesizing your day...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.dayBriefSummary.isEmpty ? "Tap refresh to load your Day Brief." : store.dayBriefSummary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
            }
        }
    }

    // MARK: - Widget Grid

    private var widgetGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Weather widget
            WidgetCardView(
                icon: store.weatherIcon,
                title: "Weather",
                value: store.weatherTemp,
                subtitle: store.weatherNote,
                color: .blue
            )

            // Next Event widget
            WidgetCardView(
                icon: "calendar",
                title: "Next Up",
                value: store.nextEventTitle.isEmpty ? "No events" : store.nextEventTitle,
                subtitle: store.nextEventTime,
                color: .purple
            )

            // Priorities count widget
            WidgetCardView(
                icon: "checklist",
                title: "Priorities",
                value: "\(store.priorities.filter { !$0.isCompleted }.count)",
                subtitle: "remaining today",
                color: .orange
            )

            // Energy widget
            WidgetCardView(
                icon: "bolt.fill",
                title: "Energy",
                value: "\(store.energyScore)/10",
                subtitle: store.energyScore >= 7 ? "Deep work ready" : "Light tasks",
                color: store.energyScore >= 7 ? .green : .yellow
            )
        }
    }

    // MARK: - Priorities

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Priorities")
                    .font(.headline)
                Spacer()
                Text("\(store.priorities.filter(\.isCompleted).count)/\(store.priorities.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.priorities.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("No priorities yet. Tap + to add one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(store.priorities) { priority in
                    PriorityCardView(
                        priority: priority,
                        onToggle: { store.send(.togglePriority(priority.id)) },
                        onDelete: { store.send(.deletePriority(priority.id)) }
                    )
                }
            }
        }
    }

    // MARK: - Add Priority Sheet

    private var addPrioritySheet: some View {
        NavigationStack {
            Form {
                Section("Priority Details") {
                    TextField("What needs to get done?", text: $store.newPriorityTitle.sending(\.newPriorityTitleChanged))

                    Picker("Category", selection: $store.newPriorityModule.sending(\.newPriorityModuleChanged)) {
                        Label("Command Center", systemImage: "bolt.fill").tag("commandCenter")
                        Label("Work", systemImage: "building.columns.fill").tag("workSuite")
                        Label("Family", systemImage: "house.fill").tag("familyHQ")
                        Label("Social", systemImage: "person.2.fill").tag("socialCircle")
                        Label("Explore", systemImage: "safari.fill").tag("explore")
                        Label("Balance", systemImage: "heart.fill").tag("balance")
                    }

                    Picker("Time Estimate", selection: $store.newPriorityTimeEstimate.sending(\.newPriorityTimeEstimateChanged)) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                }
            }
            .navigationTitle("New Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.toggleAddPriority) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addPriority) }
                        .fontWeight(.semibold)
                        .disabled(store.newPriorityTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Priority Card

struct PriorityCardView: View {
    let priority: CommandCenterReducer.State.PriorityState
    let onToggle: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: priority.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(priority.isCompleted ? .green : .secondary)
                }

                Image(systemName: priority.sourceIcon)
                    .font(.caption)
                    .foregroundStyle(Color.axisGold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(priority.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(priority.isCompleted)
                        .foregroundStyle(priority.isCompleted ? .secondary : .primary)
                    Text(priority.timeEstimate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
