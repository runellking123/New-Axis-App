import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct FamilyHQReducer {
    @ObservableState
    struct State: Equatable {
        var selectedSection: Section = .calendar
        var eventFilter: EventFilter = .all
        var events: [EventState] = []
        var mealPlan: [MealState] = []
        var goals: [GoalState] = []
        var showAddEvent = false
        var showAddGoal = false
        var newEventTitle = ""
        var newEventCategory = "activity"
        var newEventDate = Date()
        var newGoalTitle = ""
        var newGoalCategory = "personal"
        var newGoalTargetDate: Date?
        var newGoalMilestones: [String] = [""]
        var showConfetti = false
        var goalFilter: GoalFilter = .active
        var expandedGoalId: UUID?
        var selectedEventId: UUID?
        var selectedGoalId: UUID?

        // Meal Logs
        var mealLogs: [MealLogState] = []
        var showAddMealLog = false
        var newMealName = ""
        var newMealType = "lunch"
        var newMealNotes = ""
        var newMealCalories: Int = 0
        var newMealDate = Date()
        var mealLogFilter: MealLogFilter = .today

        struct MealLogState: Equatable, Identifiable {
            let id: UUID
            var mealType: String
            var name: String
            var notes: String
            var calories: Int
            var date: Date

            var mealIcon: String {
                switch mealType {
                case "breakfast": return "sunrise.fill"
                case "lunch": return "sun.max.fill"
                case "dinner": return "moon.stars.fill"
                case "snack": return "cup.and.saucer.fill"
                default: return "fork.knife"
                }
            }
        }

        enum MealLogFilter: String, CaseIterable, Equatable {
            case today = "Today"
            case week = "This Week"
            case all = "All"
        }

        var filteredMealLogs: [MealLogState] {
            let cal = Calendar.current
            switch mealLogFilter {
            case .today:
                return mealLogs.filter { cal.isDateInToday($0.date) }
            case .week:
                let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return mealLogs.filter { $0.date >= weekAgo }
            case .all:
                return mealLogs
            }
        }

        var todayCalories: Int {
            let cal = Calendar.current
            return mealLogs.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.calories }
        }

        // Chore Counter
        var choreCategories: [String] = ["Pick up kids", "Wash clothes", "Clean house", "Cook dinner", "Groceries", "Dishes", "Take out trash", "Help with homework"]
        var choreCounts: [String: [String: Int]] = [:]  // [choreName: ["drking": count, "wife": count]]
        var showChoreCounter: Bool = false

        // Shopping List
        var shoppingItems: [ShoppingItemState] = []
        var newShoppingItem = ""
        var newShoppingQuantity: Int = 1
        var newShoppingBudget: Double = 0
        var newShoppingStore: String = "Any"
        var newShoppingCategory: String = "General"
        var showShoppingList = false

        struct ShoppingItemState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var quantity: Int
            var budgetPrice: Double
            var actualPrice: Double
            var store: String
            var category: String
            var isBought: Bool
        }

        enum Section: String, CaseIterable, Equatable {
            case calendar = "Calendar"
            case meals = "Meals"
            case goals = "Goals"
        }

        enum EventFilter: String, CaseIterable, Equatable {
            case all = "All"
            case today = "Today"
            case upcoming = "Upcoming"
            case completed = "Done"
        }

        enum GoalFilter: String, CaseIterable, Equatable {
            case active = "Active"
            case completed = "Completed"
            case all = "All"
        }

        struct EventState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var category: String
            var date: Date
            var isCompleted: Bool
            var assignedTo: String

            var categoryIcon: String {
                switch category {
                case "activity": return "figure.run"
                case "appointment": return "cross.case.fill"
                case "school": return "graduationcap.fill"
                case "meal": return "fork.knife"
                case "outing": return "car.fill"
                default: return "calendar"
                }
            }
        }

        struct MealState: Equatable, Identifiable {
            var id: String { "\(dayOfWeek)-\(mealType)" }
            var dayOfWeek: Int
            var mealType: String
            var mealName: String

            var dayLabel: String {
                switch dayOfWeek {
                case 1: return "Sun"
                case 2: return "Mon"
                case 3: return "Tue"
                case 4: return "Wed"
                case 5: return "Thu"
                case 6: return "Fri"
                case 7: return "Sat"
                default: return "?"
                }
            }
        }

        struct GoalState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var category: String
            var targetDate: Date?
            var milestones: [MilestoneState]
            var notes: String
            var createdAt: Date
            var completedAt: Date?

            var isCompleted: Bool { completedAt != nil }

            var progress: Double {
                guard !milestones.isEmpty else { return 0 }
                let completed = milestones.filter(\.isCompleted).count
                return Double(completed) / Double(milestones.count)
            }

            var completedMilestoneCount: Int {
                milestones.filter(\.isCompleted).count
            }

            var categoryIcon: String {
                switch category {
                case "family": return "house.fill"
                case "career": return "briefcase.fill"
                case "health": return "heart.fill"
                case "personal": return "person.fill"
                case "financial": return "dollarsign.circle.fill"
                default: return "target"
                }
            }

            var categoryColorName: String {
                switch category {
                case "family": return "blue"
                case "career": return "orange"
                case "health": return "green"
                case "personal": return "purple"
                case "financial": return "yellow"
                default: return "gray"
                }
            }
        }

        struct MilestoneState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var isCompleted: Bool
            var sortOrder: Int
        }

        var todayEvents: [EventState] {
            events.filter { Calendar.current.isDateInToday($0.date) }
        }

        var upcomingEvents: [EventState] {
            events.filter { !Calendar.current.isDateInToday($0.date) && $0.date > Date() }
                .sorted { $0.date < $1.date }
        }

        var completedEvents: [EventState] {
            events.filter(\.isCompleted).sorted { $0.date > $1.date }
        }

        var filteredCalendarEvents: [EventState] {
            switch eventFilter {
            case .all:
                return events.sorted { $0.date < $1.date }
            case .today:
                return todayEvents
            case .upcoming:
                return upcomingEvents
            case .completed:
                return completedEvents
            }
        }

        var completedEventCount: Int {
            events.filter(\.isCompleted).count
        }

        var filteredGoals: [GoalState] {
            switch goalFilter {
            case .active:
                return goals.filter { !$0.isCompleted }
            case .completed:
                return goals.filter(\.isCompleted)
            case .all:
                return goals
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case sectionChanged(State.Section)
        case eventFilterChanged(State.EventFilter)
        case toggleAddEvent
        case dismissAddEvent
        case newEventTitleChanged(String)
        case newEventCategoryChanged(String)
        case newEventDateChanged(Date)
        case addEvent
        case toggleEventCompleted(UUID)
        case deleteEvent(UUID)
        // Goals
        case toggleAddGoal
        case dismissAddGoal
        case newGoalTitleChanged(String)
        case newGoalCategoryChanged(String)
        case newGoalTargetDateChanged(Date?)
        case newGoalMilestoneTextChanged(index: Int, text: String)
        case addGoalMilestoneField
        case removeGoalMilestoneField(Int)
        case addGoal
        case deleteGoal(UUID)
        case toggleMilestone(goalId: UUID, milestoneId: UUID)
        case goalFilterChanged(State.GoalFilter)
        case toggleGoalExpanded(UUID)
        case hideConfetti
        // Meals (legacy dinner plan)
        case mealNameChanged(dayOfWeek: Int, mealType: String, name: String)
        // Meal Logs
        case toggleAddMealLog
        case dismissAddMealLog
        case newMealNameChanged(String)
        case newMealTypeChanged(String)
        case newMealNotesChanged(String)
        case newMealCaloriesChanged(Int)
        case newMealDateChanged(Date)
        case addMealLog
        case deleteMealLog(UUID)
        case mealLogFilterChanged(State.MealLogFilter)
        case exportMealLogs
        // Chore Counter
        case toggleChoreCounter
        case dismissChoreCounter
        case loadChoreCounts
        case choreCountsLoaded([String: [String: Int]])
        case incrementChore(String, String)  // choreName, person
        case decrementChore(String, String)  // choreName, person
        case resetChoreCounts
        // Shopping List
        case toggleShoppingList
        case dismissShoppingList
        case addShoppingItem
        case newShoppingItemChanged(String)
        case newShoppingQuantityChanged(Int)
        case newShoppingBudgetChanged(Double)
        case newShoppingStoreChanged(String)
        case newShoppingCategoryChanged(String)
        case toggleShoppingItemBought(UUID)
        case updateShoppingActualPrice(UUID, Double)
        case deleteShoppingItem(UUID)
        case shareShoppingList
        // Drill-down
        case selectEvent(UUID?)
        case selectGoal(UUID?)
        case updateEventTitle(UUID, String)
        case updateEventCategory(UUID, String)
        case updateGoalTitle(UUID, String)
        case updateGoalCategory(UUID, String)
        case updateGoalNotes(UUID, String)
        case addMilestoneToGoal(UUID)
        case removeMilestoneFromGoal(goalId: UUID, milestoneId: UUID)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared

                // Events
                let storedEvents = persistence.fetchFamilyEvents()
                state.events = storedEvents.map { e in
                    State.EventState(id: e.uuid, title: e.title, category: e.category, date: e.date, isCompleted: e.isCompleted, assignedTo: e.assignedTo)
                }

                // Meal plans
                let storedMeals = persistence.fetchMealPlans()
                if storedMeals.isEmpty {
                    for day in 1...7 {
                        let plan = MealPlan(dayOfWeek: day, mealType: "dinner", mealName: "")
                        persistence.saveMealPlan(plan)
                    }
                    state.mealPlan = (1...7).map { State.MealState(dayOfWeek: $0, mealType: "dinner", mealName: "") }
                } else {
                    state.mealPlan = storedMeals.map { m in
                        State.MealState(dayOfWeek: m.dayOfWeek, mealType: m.mealType, mealName: m.mealName)
                    }
                }

                // Meal Logs
                let storedLogs = persistence.fetchMealLogs()
                state.mealLogs = storedLogs.map { l in
                    State.MealLogState(id: l.uuid, mealType: l.mealType, name: l.name, notes: l.notes, calories: l.calories, date: l.date)
                }

                // Goals
                let storedGoals = persistence.fetchGoals()
                state.goals = storedGoals.map { g in
                    let milestoneStates = g.milestones
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { m in
                            State.MilestoneState(id: m.uuid, title: m.title, isCompleted: m.isCompleted, sortOrder: m.sortOrder)
                        }
                    return State.GoalState(
                        id: g.uuid,
                        title: g.title,
                        category: g.category,
                        targetDate: g.targetDate,
                        milestones: milestoneStates,
                        notes: g.notes,
                        createdAt: g.createdAt,
                        completedAt: g.completedAt
                    )
                }

                return .none

            case let .sectionChanged(section):
                state.selectedSection = section
                return .none

            case let .eventFilterChanged(filter):
                state.eventFilter = filter
                return .none

            case .toggleAddEvent:
                state.showAddEvent.toggle()
                if state.showAddEvent {
                    state.newEventTitle = ""
                    state.newEventCategory = "activity"
                    state.newEventDate = Date()
                }
                return .none

            case .dismissAddEvent:
                state.showAddEvent = false
                return .none

            case let .newEventTitleChanged(title):
                state.newEventTitle = title
                return .none

            case let .newEventCategoryChanged(category):
                state.newEventCategory = category
                return .none

            case let .newEventDateChanged(date):
                state.newEventDate = date
                return .none

            case .addEvent:
                guard !state.newEventTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let event = FamilyEvent(
                    title: state.newEventTitle,
                    category: state.newEventCategory,
                    date: state.newEventDate,
                    isCompleted: false,
                    assignedTo: "family"
                )
                PersistenceService.shared.saveFamilyEvent(event)
                state.events.append(State.EventState(
                    id: event.uuid,
                    title: event.title,
                    category: event.category,
                    date: event.date,
                    isCompleted: event.isCompleted,
                    assignedTo: event.assignedTo
                ))
                state.showAddEvent = false
                HapticService.notification(.success)
                return .none

            case let .toggleEventCompleted(id):
                if let index = state.events.firstIndex(where: { $0.id == id }) {
                    state.events[index].isCompleted.toggle()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchFamilyEvents()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isCompleted = state.events[index].isCompleted
                        persistence.updateFamilyEvents()
                    }
                    HapticService.impact(.light)
                }
                return .none

            case let .deleteEvent(id):
                state.events.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchFamilyEvents()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteFamilyEvent(match)
                }
                return .none

            // MARK: - Goals

            case .toggleAddGoal:
                state.showAddGoal.toggle()
                if state.showAddGoal {
                    state.newGoalTitle = ""
                    state.newGoalCategory = "personal"
                    state.newGoalTargetDate = nil
                    state.newGoalMilestones = [""]
                }
                return .none

            case .dismissAddGoal:
                state.showAddGoal = false
                return .none

            case let .newGoalTitleChanged(title):
                state.newGoalTitle = title
                return .none

            case let .newGoalCategoryChanged(category):
                state.newGoalCategory = category
                return .none

            case let .newGoalTargetDateChanged(date):
                state.newGoalTargetDate = date
                return .none

            case let .newGoalMilestoneTextChanged(index, text):
                if index < state.newGoalMilestones.count {
                    state.newGoalMilestones[index] = text
                }
                return .none

            case .addGoalMilestoneField:
                state.newGoalMilestones.append("")
                return .none

            case let .removeGoalMilestoneField(index):
                guard state.newGoalMilestones.count > 1 else { return .none }
                state.newGoalMilestones.remove(at: index)
                return .none

            case .addGoal:
                guard !state.newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let goal = Goal(
                    title: state.newGoalTitle,
                    category: state.newGoalCategory,
                    targetDate: state.newGoalTargetDate
                )
                let milestoneTexts = state.newGoalMilestones.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                var milestoneStates: [State.MilestoneState] = []
                for (i, text) in milestoneTexts.enumerated() {
                    let milestone = Milestone(title: text, sortOrder: i)
                    goal.milestones.append(milestone)
                    milestoneStates.append(State.MilestoneState(id: milestone.uuid, title: milestone.title, isCompleted: false, sortOrder: i))
                }
                PersistenceService.shared.saveGoal(goal)
                state.goals.insert(State.GoalState(
                    id: goal.uuid,
                    title: goal.title,
                    category: goal.category,
                    targetDate: goal.targetDate,
                    milestones: milestoneStates,
                    notes: goal.notes,
                    createdAt: goal.createdAt,
                    completedAt: nil
                ), at: 0)
                state.showAddGoal = false
                HapticService.notification(.success)
                return .none

            case let .deleteGoal(id):
                state.goals.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchGoals()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteGoal(match)
                }
                return .none

            case let .toggleMilestone(goalId, milestoneId):
                guard let goalIndex = state.goals.firstIndex(where: { $0.id == goalId }),
                      let msIndex = state.goals[goalIndex].milestones.firstIndex(where: { $0.id == milestoneId }) else {
                    return .none
                }
                state.goals[goalIndex].milestones[msIndex].isCompleted.toggle()

                // Persist
                let persistence = PersistenceService.shared
                let stored = persistence.fetchGoals()
                if let goalMatch = stored.first(where: { $0.uuid == goalId }),
                   let msMatch = goalMatch.milestones.first(where: { $0.uuid == milestoneId }) {
                    msMatch.isCompleted = state.goals[goalIndex].milestones[msIndex].isCompleted
                    msMatch.completedAt = msMatch.isCompleted ? Date() : nil
                    // Check if goal is fully complete
                    if goalMatch.milestones.allSatisfy(\.isCompleted) && !goalMatch.milestones.isEmpty {
                        goalMatch.completedAt = Date()
                        state.goals[goalIndex].completedAt = Date()
                        state.showConfetti = true
                        HapticService.celebration()
                        persistence.updateGoals()
                        return .run { send in
                            try await Task.sleep(for: .seconds(3))
                            await send(.hideConfetti)
                        }
                    }
                    persistence.updateGoals()
                }
                HapticService.impact(.light)
                return .none

            case let .goalFilterChanged(filter):
                state.goalFilter = filter
                return .none

            case let .toggleGoalExpanded(id):
                if state.expandedGoalId == id {
                    state.expandedGoalId = nil
                } else {
                    state.expandedGoalId = id
                }
                return .none

            case let .mealNameChanged(dayOfWeek, mealType, name):
                if let index = state.mealPlan.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.mealType == mealType }) {
                    state.mealPlan[index].mealName = name
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchMealPlans()
                    if let match = stored.first(where: { $0.dayOfWeek == dayOfWeek && $0.mealType == mealType }) {
                        match.mealName = name
                        persistence.updateMealPlans()
                    }
                }
                return .none

            // MARK: - Meal Logs

            case .toggleAddMealLog:
                state.showAddMealLog.toggle()
                if state.showAddMealLog {
                    state.newMealName = ""
                    state.newMealType = "lunch"
                    state.newMealNotes = ""
                    state.newMealCalories = 0
                    state.newMealDate = Date()
                }
                return .none

            case .dismissAddMealLog:
                state.showAddMealLog = false
                return .none

            case let .newMealNameChanged(name):
                state.newMealName = name
                return .none

            case let .newMealTypeChanged(type):
                state.newMealType = type
                return .none

            case let .newMealNotesChanged(notes):
                state.newMealNotes = notes
                return .none

            case let .newMealCaloriesChanged(cal):
                state.newMealCalories = cal
                return .none

            case let .newMealDateChanged(date):
                state.newMealDate = date
                return .none

            case .addMealLog:
                let trimmed = state.newMealName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return .none }
                let log = MealLog(
                    mealType: state.newMealType,
                    name: trimmed,
                    notes: state.newMealNotes,
                    calories: state.newMealCalories,
                    date: state.newMealDate
                )
                PersistenceService.shared.saveMealLog(log)
                state.mealLogs.insert(State.MealLogState(
                    id: log.uuid, mealType: log.mealType, name: log.name,
                    notes: log.notes, calories: log.calories, date: log.date
                ), at: 0)
                state.showAddMealLog = false
                HapticService.notification(.success)
                return .none

            case let .deleteMealLog(id):
                state.mealLogs.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchMealLogs()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteMealLog(match)
                }
                return .none

            case let .mealLogFilterChanged(filter):
                state.mealLogFilter = filter
                return .none

            case .exportMealLogs:
                var csv = "Date,Meal Type,Name,Calories,Notes\n"
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                for log in state.mealLogs.sorted(by: { $0.date < $1.date }) {
                    let escapedName = log.name.replacingOccurrences(of: "\"", with: "\"\"")
                    let escapedNotes = log.notes.replacingOccurrences(of: "\"", with: "\"\"")
                    csv += "\(dateFormatter.string(from: log.date)),\(log.mealType),\"\(escapedName)\",\(log.calories),\"\(escapedNotes)\"\n"
                }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("MealLog_\(Date().formatted(.dateTime.year().month().day())).csv")
                try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let vc = scene.windows.first?.rootViewController {
                    var top = vc
                    while let p = top.presentedViewController { top = p }
                    top.present(UIActivityViewController(activityItems: [tempURL], applicationActivities: nil), animated: true)
                }
                return .none

            case .hideConfetti:
                state.showConfetti = false
                return .none

            // MARK: - Chore Counter

            case .toggleChoreCounter:
                state.showChoreCounter = true
                return .none

            case .dismissChoreCounter:
                state.showChoreCounter = false
                return .none

            case .loadChoreCounts:
                let persistence = PersistenceService.shared
                let counts = persistence.fetchChoreCounts()
                var mapped: [String: [String: Int]] = [:]
                for c in counts {
                    if mapped[c.choreName] == nil { mapped[c.choreName] = [:] }
                    mapped[c.choreName]?[c.person] = c.count
                }
                state.choreCounts = mapped
                return .none

            case let .choreCountsLoaded(counts):
                state.choreCounts = counts
                return .none

            case let .incrementChore(name, person):
                PersistenceService.shared.incrementChore(name: name, person: person)
                var counts = state.choreCounts
                var inner = counts[name] ?? [:]
                inner[person] = (inner[person] ?? 0) + 1
                counts[name] = inner
                state.choreCounts = counts
                return .none

            case let .decrementChore(name, person):
                var counts = state.choreCounts
                var inner = counts[name] ?? [:]
                let current = inner[person] ?? 0
                guard current > 0 else { return .none }
                inner[person] = current - 1
                counts[name] = inner
                state.choreCounts = counts
                PersistenceService.shared.decrementChore(name: name, person: person)
                return .none

            case .resetChoreCounts:
                PersistenceService.shared.resetWeeklyChoreCounts()
                state.choreCounts = [:]
                return .none

            // MARK: - Shopping List

            case .toggleShoppingList:
                state.showShoppingList = true
                // Load from UserDefaults
                if let data = UserDefaults.standard.data(forKey: "axis_shopping_items_v2"),
                   let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) {
                    state.shoppingItems = decoded.compactMap { dict in
                        guard let idStr = dict["id"], let id = UUID(uuidString: idStr),
                              let name = dict["name"], let boughtStr = dict["isBought"] else { return nil }
                        return State.ShoppingItemState(
                            id: id,
                            name: name,
                            quantity: Int(dict["quantity"] ?? "1") ?? 1,
                            budgetPrice: Double(dict["budgetPrice"] ?? "0") ?? 0,
                            actualPrice: Double(dict["actualPrice"] ?? "0") ?? 0,
                            store: dict["store"] ?? "Any",
                            category: dict["category"] ?? "General",
                            isBought: boughtStr == "true"
                        )
                    }
                }
                return .none

            case .dismissShoppingList:
                state.showShoppingList = false
                return .none

            case .addShoppingItem:
                let trimmed = state.newShoppingItem.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return .none }
                let item = State.ShoppingItemState(
                    id: UUID(),
                    name: trimmed,
                    quantity: state.newShoppingQuantity,
                    budgetPrice: state.newShoppingBudget,
                    actualPrice: 0,
                    store: state.newShoppingStore,
                    category: state.newShoppingCategory,
                    isBought: false
                )
                state.shoppingItems.insert(item, at: 0)
                state.newShoppingItem = ""
                state.newShoppingQuantity = 1
                state.newShoppingBudget = 0
                Self.saveShoppingItems(state.shoppingItems)
                HapticService.impact(.light)
                return .none

            case let .newShoppingItemChanged(text):
                state.newShoppingItem = text
                return .none

            case let .newShoppingQuantityChanged(qty):
                state.newShoppingQuantity = qty
                return .none

            case let .newShoppingBudgetChanged(price):
                state.newShoppingBudget = price
                return .none

            case let .newShoppingStoreChanged(store):
                state.newShoppingStore = store
                return .none

            case let .newShoppingCategoryChanged(cat):
                state.newShoppingCategory = cat
                return .none

            case let .toggleShoppingItemBought(id):
                if let index = state.shoppingItems.firstIndex(where: { $0.id == id }) {
                    state.shoppingItems[index].isBought.toggle()
                    Self.saveShoppingItems(state.shoppingItems)
                    HapticService.impact(.light)
                }
                return .none

            case let .updateShoppingActualPrice(id, price):
                if let index = state.shoppingItems.firstIndex(where: { $0.id == id }) {
                    state.shoppingItems[index].actualPrice = price
                    Self.saveShoppingItems(state.shoppingItems)
                }
                return .none

            case let .deleteShoppingItem(id):
                state.shoppingItems.removeAll { $0.id == id }
                Self.saveShoppingItems(state.shoppingItems)
                return .none

            case .shareShoppingList:
                // Build formatted text
                var text = "Shopping List\n"
                text += String(repeating: "\u{2500}", count: 30) + "\n\n"
                let stores = Set(state.shoppingItems.map(\.store))
                for store in stores.sorted() {
                    let items = state.shoppingItems.filter { $0.store == store }
                    text += "\u{1F4CD} \(store)\n"
                    for item in items {
                        let check = item.isBought ? "\u{2713}" : "\u{25CB}"
                        text += "  \(check) \(item.name) x\(item.quantity) — $\(String(format: "%.2f", item.budgetPrice))\n"
                    }
                    let storeTotal = items.reduce(0.0) { $0 + $1.budgetPrice * Double($1.quantity) }
                    text += "  Subtotal: $\(String(format: "%.2f", storeTotal))\n\n"
                }
                let grandTotal = state.shoppingItems.reduce(0.0) { $0 + $1.budgetPrice * Double($1.quantity) }
                text += "TOTAL BUDGET: $\(String(format: "%.2f", grandTotal))\n"
                // Share via UIActivityViewController
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ShoppingList.txt")
                try? text.write(to: tempURL, atomically: true, encoding: .utf8)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let vc = scene.windows.first?.rootViewController {
                    var top = vc
                    while let p = top.presentedViewController { top = p }
                    top.present(UIActivityViewController(activityItems: [tempURL], applicationActivities: nil), animated: true)
                }
                return .none

            // MARK: - Drill-down

            case let .selectEvent(id):
                state.selectedEventId = id
                return .none

            case let .selectGoal(id):
                state.selectedGoalId = id
                return .none

            case let .updateEventTitle(id, title):
                if let index = state.events.firstIndex(where: { $0.id == id }) {
                    state.events[index].title = title
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchFamilyEvents()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.title = title
                        persistence.updateFamilyEvents()
                    }
                }
                return .none

            case let .updateEventCategory(id, category):
                if let index = state.events.firstIndex(where: { $0.id == id }) {
                    state.events[index].category = category
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchFamilyEvents()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.category = category
                        persistence.updateFamilyEvents()
                    }
                }
                return .none

            case let .updateGoalTitle(id, title):
                if let index = state.goals.firstIndex(where: { $0.id == id }) {
                    state.goals[index].title = title
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchGoals()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.title = title
                        persistence.updateGoals()
                    }
                }
                return .none

            case let .updateGoalCategory(id, category):
                if let index = state.goals.firstIndex(where: { $0.id == id }) {
                    state.goals[index].category = category
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchGoals()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.category = category
                        persistence.updateGoals()
                    }
                }
                return .none

            case let .updateGoalNotes(id, notes):
                if let index = state.goals.firstIndex(where: { $0.id == id }) {
                    state.goals[index].notes = notes
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchGoals()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.notes = notes
                        persistence.updateGoals()
                    }
                }
                return .none

            case let .addMilestoneToGoal(goalId):
                if let index = state.goals.firstIndex(where: { $0.id == goalId }) {
                    let newOrder = state.goals[index].milestones.count
                    let milestone = Milestone(title: "New milestone", sortOrder: newOrder)
                    state.goals[index].milestones.append(
                        State.MilestoneState(id: milestone.uuid, title: milestone.title, isCompleted: false, sortOrder: newOrder)
                    )
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchGoals()
                    if let match = stored.first(where: { $0.uuid == goalId }) {
                        match.milestones.append(milestone)
                        persistence.updateGoals()
                    }
                }
                return .none

            case let .removeMilestoneFromGoal(goalId, milestoneId):
                if let goalIndex = state.goals.firstIndex(where: { $0.id == goalId }) {
                    state.goals[goalIndex].milestones.removeAll { $0.id == milestoneId }
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchGoals()
                    if let match = stored.first(where: { $0.uuid == goalId }) {
                        match.milestones.removeAll { $0.uuid == milestoneId }
                        persistence.updateGoals()
                    }
                }
                return .none
            }
        }
    }

    private static func saveShoppingItems(_ items: [State.ShoppingItemState]) {
        let encoded = items.map { item -> [String: String] in
            [
                "id": item.id.uuidString,
                "name": item.name,
                "quantity": "\(item.quantity)",
                "budgetPrice": "\(item.budgetPrice)",
                "actualPrice": "\(item.actualPrice)",
                "store": item.store,
                "category": item.category,
                "isBought": item.isBought ? "true" : "false"
            ]
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: "axis_shopping_items_v2")
        }
    }
}
