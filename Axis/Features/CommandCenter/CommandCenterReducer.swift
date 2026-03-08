import ComposableArchitecture
import Foundation

@Reducer
struct CommandCenterReducer {
    @ObservableState
    struct State: Equatable {
        var userName: String = "Runell"
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
        var nudges: [Nudge] = []
        var selectedPriorityId: UUID?

        struct Nudge: Equatable, Identifiable {
            let id = UUID()
            var icon: String
            var message: String
            var color: String
            var tab: String // which tab to navigate to
        }

        struct PriorityState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var sourceModule: String
            var sourceIcon: String
            var timeEstimate: String
            var isCompleted: Bool
            var contextMode: String
        }

        var filteredPriorities: [PriorityState] {
            priorities.filter { $0.contextMode == contextMode.rawValue.lowercased() || $0.contextMode == "all" }
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
        case dismissAddPriority
        case newPriorityTitleChanged(String)
        case newPriorityModuleChanged(String)
        case newPriorityTimeEstimateChanged(Int)
        case addPriority
        case nudgesUpdated([State.Nudge])
        case dismissNudge(UUID)
        // Drill-down
        case selectPriority(UUID?)
        case updatePriorityTitle(UUID, String)
        case updatePriorityTimeEstimate(UUID, Int)
    }

    @Dependency(\.axisPersistence) var persistence
    @Dependency(\.axisWeather) var weatherClient
    @Dependency(\.axisCalendar) var calendarClient
    @Dependency(\.axisAI) var aiClient
    @Dependency(\.axisHaptics) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingBrief = true
                state.currentGreeting = Self.greetingForTimeOfDay()

                // Load persisted priorities
                let stored = persistence.fetchPriorityItems()
                state.userName = persistence.getOrCreateProfile().name
                state.priorities = stored.map { item in
                    State.PriorityState(
                        id: item.uuid,
                        title: item.title,
                        sourceModule: item.sourceModule,
                        sourceIcon: item.sourceIcon,
                        timeEstimate: item.formattedTimeEstimate,
                        isCompleted: item.isCompleted,
                        contextMode: item.contextMode
                    )
                }

                // Generate nudges from cross-module data
                var nudges: [State.Nudge] = []
                let contacts = PersistenceService.shared.fetchContacts()
                let overdueContacts = contacts.filter { c in
                    guard let last = c.lastContacted else { return true }
                    let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
                    return daysSince >= c.checkInDays
                }
                if let overdue = overdueContacts.first {
                    let days = overdue.lastContacted.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999
                    let msg = overdue.lastContacted == nil
                        ? "You haven't reached out to \(overdue.name) yet"
                        : "It's been \(days) days since you talked to \(overdue.name)"
                    nudges.append(.init(icon: "person.wave.2.fill", message: msg, color: "orange", tab: "socialCircle"))
                }

                let goals = PersistenceService.shared.fetchGoals()
                for goal in goals where goal.completedAt == nil {
                    let total = goal.milestones.count
                    let done = goal.milestones.filter(\.isCompleted).count
                    if total > 0 && done > 0 {
                        let remaining = total - done
                        if remaining <= 2 {
                            nudges.append(.init(icon: "target", message: "'\(goal.title)' is \(Int(Double(done)/Double(total)*100))% complete — \(remaining) milestone\(remaining == 1 ? "" : "s") left!", color: "green", tab: "familyHQ"))
                            break
                        }
                    }
                }

                let todayPriorities = state.priorities.filter { !$0.isCompleted }
                if todayPriorities.count >= 3 {
                    nudges.append(.init(icon: "checklist", message: "\(todayPriorities.count) priorities remaining today", color: "purple", tab: "commandCenter"))
                }

                // Birthday nudges from contacts
                let cal = Calendar.current
                for contact in contacts {
                    guard let birthday = contact.birthday else { continue }
                    var components = cal.dateComponents([.month, .day], from: birthday)
                    components.year = cal.component(.year, from: Date())
                    guard var nextBday = cal.date(from: components) else { continue }
                    if nextBday < Date() { nextBday = cal.date(byAdding: .year, value: 1, to: nextBday)! }
                    let daysUntil = cal.dateComponents([.day], from: Date(), to: nextBday).day ?? 999
                    if daysUntil <= 7 && daysUntil >= 0 {
                        let msg = daysUntil == 0 ? "\(contact.name)'s birthday is today!" : "\(contact.name)'s birthday is in \(daysUntil) day\(daysUntil == 1 ? "" : "s")"
                        nudges.append(.init(icon: "gift.fill", message: msg, color: "pink", tab: "socialCircle"))
                        break
                    }
                }

                state.nudges = Array(nudges.prefix(3))

                return .run { send in
                    // Load weather
                    let weatherData = await weatherClient.fetchWeather()
                    if let data = weatherData {
                        await send(.weatherLoaded(
                            temp: data.temperatureFormatted,
                            icon: data.sfSymbol,
                            note: data.actionableNote
                        ))
                    }

                    // Load calendar
                    let granted = await calendarClient.requestAccess()
                    if granted {
                        let events = await calendarClient.fetchTodayEvents()
                        if let next = calendarClient.upcomingEvent() {
                            await send(.nextEventLoaded(
                                title: next.title,
                                time: next.formattedTime
                            ))
                        }
                        // Generate brief using live events when access granted.
                        let brief = aiClient.generateDayBriefSummary(events, [], weatherData)
                        await send(.dayBriefLoaded(brief))
                        return
                    }
                    // Generate fallback brief.
                    let brief = aiClient.generateDayBriefSummary([], [], weatherData)
                    await send(.dayBriefLoaded(brief))
                }

            case let .contextModeChanged(mode):
                state.contextMode = mode
                haptics.modeSwitch()
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
                    let stored = persistence.fetchPriorityItems()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isCompleted = state.priorities[index].isCompleted
                        match.completedAt = state.priorities[index].isCompleted ? Date() : nil
                        persistence.updatePriorityItems()
                    }

                    if state.priorities[index].isCompleted {
                        let allDone = state.priorities.allSatisfy(\.isCompleted)
                        if allDone {
                            haptics.celebration()
                        } else {
                            haptics.notificationSuccess()
                        }
                    }
                }
                return .none

            case let .deletePriority(id):
                state.priorities.removeAll { $0.id == id }
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

            case .dismissAddPriority:
                state.showAddPriority = false
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

            case let .nudgesUpdated(nudges):
                state.nudges = Array(nudges.prefix(3))
                return .none

            case let .dismissNudge(id):
                state.nudges.removeAll { $0.id == id }
                return .none

            case .addPriority:
                guard !state.newPriorityTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let modeKey = state.contextMode.rawValue.lowercased()
                let item = PriorityItem(
                    title: state.newPriorityTitle,
                    sourceModule: state.newPriorityModule,
                    timeEstimateMinutes: state.newPriorityTimeEstimate,
                    sortOrder: state.priorities.count,
                    contextMode: modeKey
                )
                persistence.savePriorityItem(item)
                state.priorities.append(State.PriorityState(
                    id: item.uuid,
                    title: item.title,
                    sourceModule: item.sourceModule,
                    sourceIcon: item.sourceIcon,
                    timeEstimate: item.formattedTimeEstimate,
                    isCompleted: false,
                    contextMode: modeKey
                ))
                state.showAddPriority = false
                haptics.notificationSuccess()
                return .none

            // MARK: - Drill-down

            case let .selectPriority(id):
                state.selectedPriorityId = id
                return .none

            case let .updatePriorityTitle(id, title):
                if let index = state.priorities.firstIndex(where: { $0.id == id }) {
                    state.priorities[index].title = title
                    let stored = persistence.fetchPriorityItems()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.title = title
                        persistence.updatePriorityItems()
                    }
                }
                return .none

            case let .updatePriorityTimeEstimate(id, mins):
                if let index = state.priorities.firstIndex(where: { $0.id == id }) {
                    let formatted = mins < 60 ? "\(mins) min" : "\(mins / 60) hr"
                    state.priorities[index].timeEstimate = formatted
                    let stored = persistence.fetchPriorityItems()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.timeEstimateMinutes = mins
                        persistence.updatePriorityItems()
                    }
                }
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

}
