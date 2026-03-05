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
        case refreshTapped
        case priorityReordered(fromOffsets: IndexSet, toOffset: Int)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingBrief = true
                state.currentGreeting = Self.greetingForTimeOfDay()
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
                    if state.priorities[index].isCompleted {
                        // Check if all done — celebration!
                        let allDone = state.priorities.allSatisfy(\.isCompleted)
                        if allDone {
                            HapticService.celebration()
                        } else {
                            HapticService.notification(.success)
                        }
                    }
                }
                return .none

            case .refreshTapped:
                state.isLoadingBrief = true
                return .send(.onAppear)

            case let .priorityReordered(from, to):
                state.priorities.move(fromOffsets: from, toOffset: to)
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
