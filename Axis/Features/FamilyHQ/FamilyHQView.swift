import ComposableArchitecture
import SwiftUI

struct FamilyHQView: View {
    @Bindable var store: StoreOf<FamilyHQReducer>

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Section picker
                    Picker("Section", selection: $store.selectedSection.sending(\.sectionChanged)) {
                        ForEach(FamilyHQReducer.State.Section.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ScrollView {
                        VStack(spacing: 16) {
                            switch store.selectedSection {
                            case .calendar:
                                calendarSection
                            case .meals:
                                mealsSection
                            case .goals:
                                goalsSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
                .background(Color(.systemGroupedBackground))

                if store.showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Family HQ")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButton
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddEvent },
                set: { newValue in
                    if !newValue { store.send(.dismissAddEvent) }
                }
            )) {
                addEventSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showAddGoal },
                set: { newValue in
                    if !newValue { store.send(.dismissAddGoal) }
                }
            )) {
                addGoalSheet
            }
            .navigationDestination(isPresented: Binding(
                get: { store.selectedEventId != nil },
                set: { if !$0 { store.send(.selectEvent(nil)) } }
            )) {
                if let id = store.selectedEventId, let event = store.events.first(where: { $0.id == id }) {
                    EventDetailView(store: store, event: event)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { store.selectedGoalId != nil },
                set: { if !$0 { store.send(.selectGoal(nil)) } }
            )) {
                if let id = store.selectedGoalId, let goal = store.goals.first(where: { $0.id == id }) {
                    GoalDetailView(store: store, goal: goal)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        switch store.selectedSection {
        case .calendar:
            Button { store.send(.toggleAddEvent) } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        case .goals:
            Button { store.send(.toggleAddGoal) } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        case .meals:
            EmptyView()
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Family Calendar")
                            .font(.headline)
                        Spacer()
                        Text("\(store.completedEventCount)/\(store.events.count) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Filter", selection: $store.eventFilter.sending(\.eventFilterChanged)) {
                        ForEach(FamilyHQReducer.State.EventFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if !store.filteredCalendarEvents.isEmpty {
                ForEach(store.filteredCalendarEvents) { event in
                    Button {
                        store.send(.selectEvent(event.id))
                    } label: {
                        eventCard(event)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.events.isEmpty {
                emptyState(icon: "calendar", message: "No family events yet. Tap + to add one.")
            } else if store.filteredCalendarEvents.isEmpty {
                emptyState(icon: "line.3.horizontal.decrease.circle", message: "No events match this filter yet.")
            }
        }
    }

    private func eventCard(_ event: FamilyHQReducer.State.EventState) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Button {
                    store.send(.toggleEventCompleted(event.id))
                } label: {
                    Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(event.isCompleted ? .green : .secondary)
                }

                Image(systemName: event.categoryIcon)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(event.isCompleted)
                        .foregroundStyle(event.isCompleted ? .secondary : .primary)
                    HStack(spacing: 4) {
                        Image(systemName: event.date.isToday ? "clock" : "calendar")
                            .font(.caption2)
                        Text(event.date.isToday ? event.date.timeString : event.date.shortDateString)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.send(.deleteEvent(event.id))
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Meals Section

    private var mealsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.blue)
                Text("This Week's Dinner Plan")
                    .font(.headline)
                Spacer()
            }

            ForEach(store.mealPlan) { meal in
                GlassCard {
                    HStack(spacing: 12) {
                        Text(meal.dayLabel)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .frame(width: 36)

                        TextField("Plan dinner...", text: Binding(
                            get: { meal.mealName },
                            set: { newValue in
                                store.send(.mealNameChanged(dayOfWeek: meal.dayOfWeek, mealType: meal.mealType, name: newValue))
                            }
                        ))
                        .font(.subheadline)
                        .textFieldStyle(.plain)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(spacing: 12) {
            // Filter
            Picker("Filter", selection: $store.goalFilter.sending(\.goalFilterChanged)) {
                ForEach(FamilyHQReducer.State.GoalFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if store.filteredGoals.isEmpty {
                emptyState(icon: "target", message: store.goalFilter == .active ? "No active goals. Tap + to set one." : "No completed goals yet.")
            } else {
                ForEach(store.filteredGoals) { goal in
                    Button {
                        store.send(.selectGoal(goal.id))
                    } label: {
                        goalCard(goal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func goalCard(_ goal: FamilyHQReducer.State.GoalState) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: goal.categoryIcon)
                        .foregroundStyle(categoryColor(goal.category))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 6) {
                            Text(goal.category.capitalized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(categoryColor(goal.category).opacity(0.15))
                                .foregroundStyle(categoryColor(goal.category))
                                .clipShape(Capsule())

                            if let targetDate = goal.targetDate {
                                Text(targetDate.shortDateString)
                                    .font(.caption2)
                                    .foregroundStyle(targetDate < Date() && !goal.isCompleted ? .red : .secondary)
                            }
                        }
                    }

                    Spacer()

                    if goal.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        store.send(.deleteGoal(goal.id))
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress bar
                if !goal.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(goal.isCompleted ? Color.green : categoryColor(goal.category))
                                    .frame(width: geometry.size.width * goal.progress, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(goal.completedMilestoneCount) of \(goal.milestones.count) milestones")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Expandable milestones
                if store.expandedGoalId == goal.id {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(goal.milestones.sorted { $0.sortOrder < $1.sortOrder }) { ms in
                            Button {
                                store.send(.toggleMilestone(goalId: goal.id, milestoneId: ms.id))
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: ms.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundStyle(ms.isCompleted ? .green : .secondary)
                                    Text(ms.title)
                                        .font(.caption)
                                        .strikethrough(ms.isCompleted)
                                        .foregroundStyle(ms.isCompleted ? .secondary : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }

                // Expand/collapse button
                if !goal.milestones.isEmpty {
                    Button {
                        store.send(.toggleGoalExpanded(goal.id))
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.expandedGoalId == goal.id ? "Hide milestones" : "Show milestones")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Image(systemName: store.expandedGoalId == goal.id ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "family": return .blue
        case "career": return .orange
        case "health": return .green
        case "personal": return .purple
        case "financial": return .yellow
        default: return .gray
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Add Event Sheet

    private var addEventSheet: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $store.newEventTitle.sending(\.newEventTitleChanged))

                    Picker("Category", selection: $store.newEventCategory.sending(\.newEventCategoryChanged)) {
                        Label("Activity", systemImage: "figure.run").tag("activity")
                        Label("Appointment", systemImage: "cross.case.fill").tag("appointment")
                        Label("School", systemImage: "graduationcap.fill").tag("school")
                        Label("Meal", systemImage: "fork.knife").tag("meal")
                        Label("Outing", systemImage: "car.fill").tag("outing")
                    }

                    DatePicker("Date & Time", selection: $store.newEventDate.sending(\.newEventDateChanged))
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddEvent) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addEvent) }
                        .fontWeight(.semibold)
                        .disabled(store.newEventTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Goal Sheet

    private var addGoalSheet: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal title", text: $store.newGoalTitle.sending(\.newGoalTitleChanged))

                    Picker("Category", selection: $store.newGoalCategory.sending(\.newGoalCategoryChanged)) {
                        Label("Family", systemImage: "house.fill").tag("family")
                        Label("Career", systemImage: "briefcase.fill").tag("career")
                        Label("Health", systemImage: "heart.fill").tag("health")
                        Label("Personal", systemImage: "person.fill").tag("personal")
                        Label("Financial", systemImage: "dollarsign.circle.fill").tag("financial")
                    }

                    Toggle("Set Target Date", isOn: Binding(
                        get: { store.newGoalTargetDate != nil },
                        set: { enabled in
                            store.send(.newGoalTargetDateChanged(enabled ? Date().addingTimeInterval(2592000) : nil))
                        }
                    ))

                    if let targetDate = store.newGoalTargetDate {
                        DatePicker("Target Date", selection: Binding(
                            get: { targetDate },
                            set: { store.send(.newGoalTargetDateChanged($0)) }
                        ), displayedComponents: .date)
                    }
                }

                Section("Milestones") {
                    ForEach(store.newGoalMilestones.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Milestone \(index + 1)", text: Binding(
                                get: { store.newGoalMilestones[index] },
                                set: { store.send(.newGoalMilestoneTextChanged(index: index, text: $0)) }
                            ))
                            .font(.subheadline)

                            if store.newGoalMilestones.count > 1 {
                                Button {
                                    store.send(.removeGoalMilestoneField(index))
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    Button {
                        store.send(.addGoalMilestoneField)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Add Milestone")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddGoal) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { store.send(.addGoal) }
                        .fontWeight(.semibold)
                        .disabled(store.newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
