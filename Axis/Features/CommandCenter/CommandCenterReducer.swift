import ComposableArchitecture
import Foundation

@Reducer
struct CommandCenterReducer {
    @ObservableState
    struct State: Equatable {
        var contextMode: ContextMode = .work
        var dayBriefSummary: String = ""
        var priorities: [PriorityState] = []
        var isLoadingBrief: Bool = false
        var weatherTemp: String = "75°"
        var weatherIcon: String = "sun.max.fill"
        var weatherNote: String = "Clear skies — great day."
        var nextEventTitle: String = ""
        var nextEventTime: String = ""
        var energyScore: Int = 7
        var currentGreeting: String = "Good morning"
        var showAddPriority = false
        var newPriorityTitle = ""
        var newPriorityModule = "commandCenter"
        var newPriorityTimeEstimate = 30

        struct PriorityState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var sourceModule: String
            var sourceIcon: String
            var timeEstimate: String
            var isCompleted: Bool
        }
    }

    enum Action: Equatable {
        case onAppear
        case contextModeChanged(ContextMode)
        case dayBriefLoaded(String)
        case weatherLoaded(temp: String, icon: String, note: String)
        case nextEventLoaded(title: String, time: String)
        case prioritiesLoaded([State.PriorityState])
        case togglePriority(UUID)
        case deletePriority(UUID)
        case refreshTapped
        case priorityReordered(fromOffsets: IndexSet, toOffset: Int)
        case toggleAddPriority
        case newPriorityTitleChanged(String)
        case newPriorityModuleChanged(String)
        case newPriorityTimeEstimateChanged(Int)
        case addPriority
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingBrief = true
                state.currentGreeting = Self.greetingForTimeOfDay()

                // Load persisted priorities
                let persistence = PersistenceService.shared
                let stored = persistence.fetchPriorityItems()
                if stored.isEmpty {
                    // Seed sample priorities
                    let samples = Self.samplePriorities()
                    for (index, s) in samples.enumerated() {
                        let item = PriorityItem(
                            title: s.title,
                            sourceModule: s.sourceModule,
                            timeEstimateMinutes: 30,
                            sortOrder: index,
                            contextMode: "work"
                        )
                        persistence.savePriorityItem(item)
                        state.priorities.append(State.PriorityState(
                            id: item.uuid,
                            title: item.title,
                            sourceModule: item.sourceModule,
                            sourceIcon: item.sourceIcon,
                            timeEstimate: item.formattedTimeEstimate,
                            isCompleted: item.isCompleted
                        ))
                    }
                } else {
                    state.priorities = stored.map { item in
                        State.PriorityState(
                            id: item.uuid,
                            title: item.title,
                            sourceModule: item.sourceModule,
                            sourceIcon: item.sourceIcon,
                            timeEstimate: item.formattedTimeEstimate,
                            isCompleted: item.isCompleted
                        )
                    }
                }

                return .run { send in
                    // Load weather
                    let weather = WeatherService.shared
                    await weather.fetchWeather()
                    if let data = weather.currentWeather {
                        await send(.weatherLoaded(
                            temp: data.temperatureFormatted,
                            icon: data.sfSymbol,
                            note: data.actionableNote
                        ))
                    }

                    // Load calendar
                    let calendar = CalendarService.shared
                    let granted = await calendar.requestAccess()
                    if granted {
                        await calendar.fetchTodayEvents()
                        if let next = calendar.upcomingEvent() {
                            await send(.nextEventLoaded(
                                title: next.title,
                                time: next.formattedTime
                            ))
                        }
                    }

                    // Generate brief
                    let brief = AIService.shared.generateDayBriefSummary(
                        events: calendar.todayEvents,
                        priorities: [],
                        weather: weather.currentWeather
                    )
                    await send(.dayBriefLoaded(brief))
                }

            case let .contextModeChanged(mode):
                state.contextMode = mode
                HapticService.modeSwitch()
                return .none

            case let .dayBriefLoaded(summary):
                state.dayBriefSummary = summary
                state.isLoadingBrief = false
                return .none

            case let .weatherLoaded(temp, icon, note):
                state.weatherTemp = temp
                state.weatherIcon = icon
                state.weatherNote = note
                return .none

            case let .nextEventLoaded(title, time):
                state.nextEventTitle = title
                state.nextEventTime = time
                return .none

            case let .prioritiesLoaded(priorities):
                state.priorities = priorities
                return .none

            case let .togglePriority(id):
                if let index = state.priorities.firstIndex(where: { $0.id == id }) {
                    state.priorities[index].isCompleted.toggle()

                    // Persist
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchPriorityItems()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isCompleted = state.priorities[index].isCompleted
                        match.completedAt = state.priorities[index].isCompleted ? Date() : nil
                        persistence.updatePriorityItems()
                    }

                    if state.priorities[index].isCompleted {
                        let allDone = state.priorities.allSatisfy(\.isCompleted)
                        if allDone {
                            HapticService.celebration()
                        } else {
                            HapticService.notification(.success)
                        }
                    }
                }
                return .none

            case let .deletePriority(id):
                state.priorities.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchPriorityItems()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deletePriorityItem(match)
                }
                return .none

            case .refreshTapped:
                state.isLoadingBrief = true
                return .send(.onAppear)

            case let .priorityReordered(from, to):
                state.priorities.move(fromOffsets: from, toOffset: to)
                // Persist new sort order
                let persistence = PersistenceService.shared
                let stored = persistence.fetchPriorityItems()
                for (index, priority) in state.priorities.enumerated() {
                    if let match = stored.first(where: { $0.uuid == priority.id }) {
                        match.sortOrder = index
                    }
                }
                persistence.updatePriorityItems()
                return .none

            case .toggleAddPriority:
                state.showAddPriority.toggle()
                if state.showAddPriority {
                    state.newPriorityTitle = ""
                    state.newPriorityModule = "commandCenter"
                    state.newPriorityTimeEstimate = 30
                }
                return .none

            case let .newPriorityTitleChanged(title):
                state.newPriorityTitle = title
                return .none

            case let .newPriorityModuleChanged(module):
                state.newPriorityModule = module
                return .none

            case let .newPriorityTimeEstimateChanged(mins):
                state.newPriorityTimeEstimate = mins
                return .none

            case .addPriority:
                guard !state.newPriorityTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let item = PriorityItem(
                    title: state.newPriorityTitle,
                    sourceModule: state.newPriorityModule,
                    timeEstimateMinutes: state.newPriorityTimeEstimate,
                    sortOrder: state.priorities.count
                )
                PersistenceService.shared.savePriorityItem(item)
                state.priorities.append(State.PriorityState(
                    id: item.uuid,
                    title: item.title,
                    sourceModule: item.sourceModule,
                    sourceIcon: item.sourceIcon,
                    timeEstimate: item.formattedTimeEstimate,
                    isCompleted: false
                ))
                state.showAddPriority = false
                HapticService.notification(.success)
                return .none
            }
        }
    }

    private static func greetingForTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private static func samplePriorities() -> [(title: String, sourceModule: String)] {
        [
            ("Review sprint tasks", "workSuite"),
            ("Pick up groceries", "familyHQ"),
            ("Call Mom", "socialCircle"),
        ]
    }
}
