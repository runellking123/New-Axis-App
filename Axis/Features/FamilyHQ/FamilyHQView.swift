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
                            // Chore Counter Button
                            Button { store.send(.toggleChoreCounter) } label: {
                                GlassCard {
                                    HStack {
                                        Image(systemName: "chart.bar.fill")
                                            .foregroundStyle(Color.axisGold)
                                        Text("Chore Counter")
                                            .font(.headline)
                                            .foregroundStyle(Color.axisGold)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Shopping List Button
                            Button { store.send(.toggleShoppingList) } label: {
                                GlassCard {
                                    HStack {
                                        Image(systemName: "cart.fill")
                                            .foregroundStyle(.green)
                                        Text("Shopping List")
                                            .font(.headline)
                                            .foregroundStyle(.green)
                                        Spacer()
                                        let boughtCount = store.shoppingItems.filter(\.isBought).count
                                        if !store.shoppingItems.isEmpty {
                                            Text("\(boughtCount)/\(store.shoppingItems.count)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

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
            .sheet(isPresented: Binding(
                get: { store.showChoreCounter },
                set: { _ in store.send(.dismissChoreCounter) }
            )) {
                choreCounterSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showShoppingList },
                set: { _ in store.send(.dismissShoppingList) }
            )) {
                shoppingListSheet
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
                        Button {
                            store.send(.eventFilterChanged(store.eventFilter == .completed ? .all : .completed))
                        } label: {
                            Text("\(store.completedEventCount)/\(store.events.count) done")
                                .font(.caption)
                                .foregroundStyle(store.eventFilter == .completed ? .green : .secondary)
                        }
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
            .scrollDismissesKeyboard(.immediately)
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

    // MARK: - Chore Counter Sheet

    private var choreCounterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall scoreboard
                    let dkTotal = totalFor("drking")
                    let wifeTotal = totalFor("wife")
                    let grandTotal = max(dkTotal + wifeTotal, 1)

                    HStack(spacing: 0) {
                        // Dr. King side
                        VStack(spacing: 4) {
                            Text("\(dkTotal)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.axisGold)
                            Text("Dr. King")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        // Progress bar
                        GeometryReader { geo in
                            let goldWidth = geo.size.width * CGFloat(dkTotal) / CGFloat(grandTotal)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.purple.opacity(0.3)).frame(height: 12)
                                Capsule().fill(Color.axisGold).frame(width: max(goldWidth, 6), height: 12)
                            }
                        }
                        .frame(height: 12)
                        .frame(maxWidth: .infinity)

                        // Wife side
                        VStack(spacing: 4) {
                            Text("\(wifeTotal)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.purple)
                            Text("Wife")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 16))

                    // Chore rows — progress bar style
                    ForEach(store.choreCategories, id: \.self) { chore in
                        let dk = store.choreCounts[chore]?["drking"] ?? 0
                        let wife = store.choreCounts[chore]?["wife"] ?? 0
                        let total = max(dk + wife, 1)

                        VStack(spacing: 6) {
                            Text(chore)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            HStack(spacing: 8) {
                                // Dr. King -/+
                                Button { store.send(.decrementChore(chore, "drking")) } label: {
                                    Image(systemName: "minus")
                                        .font(.caption2).fontWeight(.bold)
                                        .frame(width: 24, height: 24)
                                        .background(Color(.systemGray5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(dk)")
                                    .font(.caption).fontWeight(.bold).monospacedDigit()
                                    .foregroundStyle(Color.axisGold)
                                    .frame(width: 24)

                                Button { store.send(.incrementChore(chore, "drking")) } label: {
                                    Image(systemName: "plus")
                                        .font(.caption2).fontWeight(.bold)
                                        .frame(width: 24, height: 24)
                                        .background(Color.axisGold.opacity(0.2))
                                        .foregroundStyle(Color.axisGold)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                // Tug-of-war bar
                                GeometryReader { geo in
                                    let goldW = geo.size.width * CGFloat(dk) / CGFloat(total)
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.purple.opacity(0.25)).frame(height: 8)
                                        Capsule().fill(Color.axisGold).frame(width: max(goldW, 4), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                // Wife +/-
                                Button { store.send(.decrementChore(chore, "wife")) } label: {
                                    Image(systemName: "minus")
                                        .font(.caption2).fontWeight(.bold)
                                        .frame(width: 24, height: 24)
                                        .background(Color(.systemGray5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(wife)")
                                    .font(.caption).fontWeight(.bold).monospacedDigit()
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)

                                Button { store.send(.incrementChore(chore, "wife")) } label: {
                                    Image(systemName: "plus")
                                        .font(.caption2).fontWeight(.bold)
                                        .frame(width: 24, height: 24)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundStyle(.purple)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Export + Reset
                    Button { exportChoreCSV() } label: {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.axisGold.opacity(0.15))
                            .foregroundStyle(Color.axisGold)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Button("Reset Weekly Counts", role: .destructive) {
                        store.send(.resetChoreCounts)
                    }
                    .font(.caption)
                }
                .padding()
            }
            .navigationTitle("Chore Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.dismissChoreCounter) }
                }
            }
            .onAppear { store.send(.loadChoreCounts) }
        }
    }

    // MARK: - Shopping List Sheet

    private let shoppingStores = ["Any", "Kroger", "Walmart", "Fresh", "H-E-B", "Sam's Club", "Target", "Dollar General", "Aldi", "Other"]
    private let shoppingCategories = ["General", "Produce", "Meat", "Dairy", "Frozen", "Household", "Snacks", "Beverages", "Other"]

    private var shoppingListSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Add item form
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        TextField("Add item...", text: $store.newShoppingItem.sending(\.newShoppingItemChanged))
                            .font(.subheadline)
                            .onSubmit { store.send(.addShoppingItem) }
                    }

                    HStack(spacing: 8) {
                        // Store picker
                        Picker("Store", selection: $store.newShoppingStore.sending(\.newShoppingStoreChanged)) {
                            ForEach(shoppingStores, id: \.self) { s in Text(s).tag(s) }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)

                        // Category picker
                        Picker("Category", selection: $store.newShoppingCategory.sending(\.newShoppingCategoryChanged)) {
                            ForEach(shoppingCategories, id: \.self) { c in Text(c).tag(c) }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                    }

                    HStack(spacing: 12) {
                        // Quantity stepper
                        HStack(spacing: 4) {
                            Text("Qty:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper("\(store.newShoppingQuantity)", value: $store.newShoppingQuantity.sending(\.newShoppingQuantityChanged), in: 1...99)
                                .font(.caption)
                        }

                        // Budget price
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: $store.newShoppingBudget.sending(\.newShoppingBudgetChanged), format: .number)
                                .font(.caption)
                                .keyboardType(.decimalPad)
                                .frame(width: 60)
                        }

                        Spacer()

                        if !store.newShoppingItem.isEmpty {
                            Button { store.send(.addShoppingItem) } label: {
                                Text("Add")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                // Summary card
                if !store.shoppingItems.isEmpty {
                    let grandTotal = store.shoppingItems.reduce(0.0) { $0 + $1.budgetPrice * Double($1.quantity) }
                    let boughtTotal = store.shoppingItems.filter(\.isBought).reduce(0.0) { $0 + $1.budgetPrice * Double($1.quantity) }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Budget Total")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(String(format: "%.2f", grandTotal))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        VStack(alignment: .center, spacing: 2) {
                            Text("Bought")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(String(format: "%.2f", boughtTotal))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Remaining")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(String(format: "%.2f", grandTotal - boughtTotal))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }

                // Items list grouped by store
                if store.shoppingItems.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "cart")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No items yet. Add something above!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    let stores = Array(Set(store.shoppingItems.map(\.store))).sorted()
                    List {
                        ForEach(stores, id: \.self) { storeName in
                            let storeItems = store.shoppingItems.filter { $0.store == storeName }
                            let unbought = storeItems.filter { !$0.isBought }
                            let bought = storeItems.filter(\.isBought)
                            let storeTotal = storeItems.reduce(0.0) { $0 + $1.budgetPrice * Double($1.quantity) }

                            Section {
                                ForEach(unbought) { item in
                                    shoppingItemRow(item)
                                }
                                ForEach(bought) { item in
                                    shoppingItemRow(item)
                                }
                            } header: {
                                HStack {
                                    Text(storeName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", storeTotal))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.shareShoppingList)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.dismissShoppingList) }
                }
            }
        }
    }

    private func shoppingItemRow(_ item: FamilyHQReducer.State.ShoppingItemState) -> some View {
        HStack(spacing: 10) {
            Button {
                store.send(.toggleShoppingItemBought(item.id))
            } label: {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isBought ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .strikethrough(item.isBought)
                    .foregroundStyle(item.isBought ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text("x\(item.quantity)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !item.category.isEmpty && item.category != "General" {
                        Text(item.category)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if item.budgetPrice > 0 {
                Text("$\(String(format: "%.2f", item.budgetPrice * Double(item.quantity)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isBought ? .green : .primary)
            }

            Button {
                store.send(.deleteShoppingItem(item.id))
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func totalFor(_ person: String) -> Int {
        store.choreCounts.values.reduce(0) { $0 + ($1[person] ?? 0) }
    }

    private func exportChoreCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let dateStr = dateFormatter.string(from: Date())

        var csv = "AXIS Chore Counter Report\n"
        csv += "Week of \(dateStr)\n\n"
        csv += "Chore,Dr. King,Wife,Total\n"

        for chore in store.choreCategories {
            let dk = store.choreCounts[chore]?["drking"] ?? 0
            let wife = store.choreCounts[chore]?["wife"] ?? 0
            csv += "\(chore),\(dk),\(wife),\(dk + wife)\n"
        }

        let dkTotal = totalFor("drking")
        let wifeTotal = totalFor("wife")
        csv += "\nTOTAL,\(dkTotal),\(wifeTotal),\(dkTotal + wifeTotal)\n"

        let fileName = "ChoreCounter_\(dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "_")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            topVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    FamilyHQView(
        store: Store(initialState: FamilyHQReducer.State()) {
            FamilyHQReducer()
        }
    )
}
