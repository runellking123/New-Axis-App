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
        var dadWins: [DadWinState] = []
        var showAddEvent = false
        var showAddDadWin = false
        var newEventTitle = ""
        var newEventCategory = "activity"
        var newEventDate = Date()
        var newDadWinTitle = ""
        var newDadWinDetails = ""
        var newDadWinMood = "proud"
        var newDadWinPhotoData: Data?
        var showConfetti = false

        enum Section: String, CaseIterable, Equatable {
            case calendar = "Calendar"
            case meals = "Meals"
            case dadWins = "Dad Wins"
        }

        enum EventFilter: String, CaseIterable, Equatable {
            case all = "All"
            case today = "Today"
            case upcoming = "Upcoming"
            case completed = "Done"
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

        struct DadWinState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var details: String
            var mood: String
            var date: Date
            var hasPhoto: Bool

            var moodIcon: String {
                switch mood {
                case "proud": return "star.fill"
                case "grateful": return "heart.fill"
                case "joyful": return "face.smiling.inverse"
                case "peaceful": return "leaf.fill"
                case "accomplished": return "trophy.fill"
                default: return "star.fill"
                }
            }

            var moodColor: String {
                switch mood {
                case "proud": return "yellow"
                case "grateful": return "pink"
                case "joyful": return "orange"
                case "peaceful": return "green"
                case "accomplished": return "purple"
                default: return "yellow"
                }
            }
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
    }

    enum Action: Equatable {
        case onAppear
        case sectionChanged(State.Section)
        case eventFilterChanged(State.EventFilter)
        case toggleAddEvent
        case toggleAddDadWin
        case newEventTitleChanged(String)
        case newEventCategoryChanged(String)
        case newEventDateChanged(Date)
        case addEvent
        case toggleEventCompleted(UUID)
        case deleteEvent(UUID)
        case newDadWinTitleChanged(String)
        case newDadWinDetailsChanged(String)
        case newDadWinMoodChanged(String)
        case newDadWinPhotoDataChanged(Data?)
        case addDadWin
        case deleteDadWin(UUID)
        case mealNameChanged(dayOfWeek: Int, mealType: String, name: String)
        case hideConfetti
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared

                // Events
                let storedEvents = persistence.fetchFamilyEvents()
                if storedEvents.isEmpty {
                    let samples = Self.sampleEvents()
                    for s in samples {
                        let event = FamilyEvent(title: s.title, category: s.category, date: s.date, isCompleted: s.isCompleted, assignedTo: s.assignedTo)
                        persistence.saveFamilyEvent(event)
                        state.events.append(State.EventState(id: event.uuid, title: event.title, category: event.category, date: event.date, isCompleted: event.isCompleted, assignedTo: event.assignedTo))
                    }
                } else {
                    state.events = storedEvents.map { e in
                        State.EventState(id: e.uuid, title: e.title, category: e.category, date: e.date, isCompleted: e.isCompleted, assignedTo: e.assignedTo)
                    }
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

                // Dad Wins
                let storedWins = persistence.fetchDadWins()
                if storedWins.isEmpty {
                    let samples = Self.sampleDadWins()
                    for s in samples {
                        let win = DadWin(title: s.title, details: s.details, mood: s.mood, date: s.date)
                        persistence.saveDadWin(win)
                        state.dadWins.append(State.DadWinState(id: win.uuid, title: win.title, details: win.details, mood: win.mood, date: win.date, hasPhoto: false))
                    }
                } else {
                    state.dadWins = storedWins.map { w in
                        State.DadWinState(id: w.uuid, title: w.title, details: w.details, mood: w.mood, date: w.date, hasPhoto: w.photoData != nil)
                    }
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

            case .toggleAddDadWin:
                state.showAddDadWin.toggle()
                if state.showAddDadWin {
                    state.newDadWinTitle = ""
                    state.newDadWinDetails = ""
                    state.newDadWinMood = "proud"
                    state.newDadWinPhotoData = nil
                }
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

            case let .newDadWinTitleChanged(title):
                state.newDadWinTitle = title
                return .none

            case let .newDadWinDetailsChanged(details):
                state.newDadWinDetails = details
                return .none

            case let .newDadWinMoodChanged(mood):
                state.newDadWinMood = mood
                return .none

            case let .newDadWinPhotoDataChanged(data):
                state.newDadWinPhotoData = data
                return .none

            case .addDadWin:
                guard !state.newDadWinTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let win = DadWin(
                    title: state.newDadWinTitle,
                    details: state.newDadWinDetails,
                    mood: state.newDadWinMood,
                    date: Date(),
                    photoData: state.newDadWinPhotoData
                )
                PersistenceService.shared.saveDadWin(win)
                state.dadWins.insert(State.DadWinState(
                    id: win.uuid,
                    title: win.title,
                    details: win.details,
                    mood: win.mood,
                    date: win.date,
                    hasPhoto: win.photoData != nil
                ), at: 0)
                state.showAddDadWin = false
                state.showConfetti = true
                HapticService.celebration()
                return .run { send in
                    try await Task.sleep(for: .seconds(3))
                    await send(.hideConfetti)
                }

            case let .deleteDadWin(id):
                state.dadWins.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchDadWins()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteDadWin(match)
                }
                return .none

            case let .mealNameChanged(dayOfWeek, mealType, name):
                if let index = state.mealPlan.firstIndex(where: { $0.dayOfWeek == dayOfWeek && $0.mealType == mealType }) {
                    state.mealPlan[index].mealName = name
                    // Persist
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
            }
        }
    }

    private static func sampleEvents() -> [State.EventState] {
        [
            .init(id: UUID(), title: "Soccer Practice", category: "activity", date: Date(), isCompleted: false, assignedTo: "runell"),
            .init(id: UUID(), title: "Family Dinner at Grandma's", category: "meal", date: Date(), isCompleted: false, assignedTo: "family"),
            .init(id: UUID(), title: "Pediatrician Appointment", category: "appointment", date: Date().addingTimeInterval(86400), isCompleted: false, assignedTo: "morgan"),
        ]
    }

    private static func sampleDadWins() -> [State.DadWinState] {
        [
            .init(id: UUID(), title: "Helped with homework", details: "Worked through long division together. The lightbulb moment was priceless.", mood: "proud", date: Date().addingTimeInterval(-86400), hasPhoto: false),
            .init(id: UUID(), title: "Morning pancakes", details: "Made chocolate chip pancakes before school. Everyone loved them.", mood: "joyful", date: Date().addingTimeInterval(-172800), hasPhoto: false),
        ]
    }
}
