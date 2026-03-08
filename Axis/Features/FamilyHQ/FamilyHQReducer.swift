import ComposableArchitecture
import Foundation

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
        // Meals
        case mealNameChanged(dayOfWeek: Int, mealType: String, name: String)
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

            case .hideConfetti:
                state.showConfetti = false
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

}
