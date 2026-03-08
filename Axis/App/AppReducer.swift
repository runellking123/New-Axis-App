import ComposableArchitecture
import Foundation

// MARK: - Dependency Clients

struct AxisPersistenceClient {
    var getOrCreateProfile: @Sendable () -> UserProfile
    var fetchPriorityItems: @Sendable () -> [PriorityItem]
    var savePriorityItem: @Sendable (PriorityItem) -> Void
    var updatePriorityItems: @Sendable () -> Void
    var deletePriorityItem: @Sendable (PriorityItem) -> Void
    var updateUserProfile: @Sendable () -> Void
}

struct AxisHapticsClient {
    var modeSwitch: @Sendable () -> Void
    var celebration: @Sendable () -> Void
    var notificationSuccess: @Sendable () -> Void
    var selection: @Sendable () -> Void
}

struct AxisWeatherClient {
    var fetchWeather: @Sendable () async -> WeatherService.WeatherData?
}

struct AxisCalendarClient {
    var requestAccess: @Sendable () async -> Bool
    var fetchTodayEvents: @Sendable () async -> [CalendarService.CalendarEvent]
    var upcomingEvent: @Sendable () -> CalendarService.CalendarEvent?
}

struct AxisAIClient {
    var generateDayBriefSummary: @Sendable ([CalendarService.CalendarEvent], [PriorityItem], WeatherService.WeatherData?) -> String
    var generateWeeklyReport: @Sendable (Int) -> AIService.WeeklyReport
}

struct AxisHealthClient {
    var isAuthorized: @Sendable () async -> Bool
    var isAvailable: @Sendable () async -> Bool
    var requestAuthorization: @Sendable () async -> Bool
    var fetchAllData: @Sendable () async -> (sleep: Double, steps: Int, energy: Int)
}

struct AxisNotificationsClient {
    var requestAuthorization: @Sendable () async -> Bool
    var scheduleDayBrief: @Sendable (Date) -> Void
    var cancelDayBrief: @Sendable () -> Void
}

private enum AxisPersistenceKey: DependencyKey {
    static let liveValue = AxisPersistenceClient(
        getOrCreateProfile: { PersistenceService.shared.getOrCreateProfile() },
        fetchPriorityItems: { PersistenceService.shared.fetchPriorityItems() },
        savePriorityItem: { PersistenceService.shared.savePriorityItem($0) },
        updatePriorityItems: { PersistenceService.shared.updatePriorityItems() },
        deletePriorityItem: { PersistenceService.shared.deletePriorityItem($0) },
        updateUserProfile: { PersistenceService.shared.updateUserProfile() }
    )
}

private enum AxisHapticsKey: DependencyKey {
    static let liveValue = AxisHapticsClient(
        modeSwitch: { HapticService.modeSwitch() },
        celebration: { HapticService.celebration() },
        notificationSuccess: { HapticService.notification(.success) },
        selection: { HapticService.selection() }
    )
}

private enum AxisWeatherKey: DependencyKey {
    static let liveValue = AxisWeatherClient(
        fetchWeather: {
            let location = LocationService.shared
            location.requestPermission()
            let weather = WeatherService.shared
            await weather.fetchWeather()
            return weather.currentWeather
        }
    )
}

private enum AxisCalendarKey: DependencyKey {
    static let liveValue = AxisCalendarClient(
        requestAccess: { await CalendarService.shared.requestAccess() },
        fetchTodayEvents: {
            let calendar = CalendarService.shared
            await calendar.fetchTodayEvents()
            return calendar.todayEvents
        },
        upcomingEvent: { CalendarService.shared.upcomingEvent() }
    )
}

private enum AxisAIKey: DependencyKey {
    static let liveValue = AxisAIClient(
        generateDayBriefSummary: { events, priorities, weather in
            AIService.shared.generateDayBriefSummary(events: events, priorities: priorities, weather: weather)
        },
        generateWeeklyReport: { days in AIService.shared.generateWeeklyReport(days: days) }
    )
}

private enum AxisHealthKey: DependencyKey {
    static let liveValue = AxisHealthClient(
        isAuthorized: { await MainActor.run { HealthKitService.shared.isAuthorized } },
        isAvailable: { await MainActor.run { HealthKitService.shared.isAvailable } },
        requestAuthorization: {
            let hk = await MainActor.run { HealthKitService.shared }
            return await hk.requestAuthorization()
        },
        fetchAllData: {
            let hk = await MainActor.run { HealthKitService.shared }
            await hk.fetchAllData()
            return await MainActor.run { (hk.sleepHours, hk.stepsToday, hk.energyScore) }
        }
    )
}

private enum AxisNotificationsKey: DependencyKey {
    static let liveValue = AxisNotificationsClient(
        requestAuthorization: { await NotificationService.shared.requestAuthorization() },
        scheduleDayBrief: { wakeTime in NotificationService.shared.scheduleDayBrief(at: wakeTime) },
        cancelDayBrief: { NotificationService.shared.cancelAll(withPrefix: "day-brief") }
    )
}

extension DependencyValues {
    var axisPersistence: AxisPersistenceClient {
        get { self[AxisPersistenceKey.self] }
        set { self[AxisPersistenceKey.self] = newValue }
    }

    var axisHaptics: AxisHapticsClient {
        get { self[AxisHapticsKey.self] }
        set { self[AxisHapticsKey.self] = newValue }
    }

    var axisWeather: AxisWeatherClient {
        get { self[AxisWeatherKey.self] }
        set { self[AxisWeatherKey.self] = newValue }
    }

    var axisCalendar: AxisCalendarClient {
        get { self[AxisCalendarKey.self] }
        set { self[AxisCalendarKey.self] = newValue }
    }

    var axisAI: AxisAIClient {
        get { self[AxisAIKey.self] }
        set { self[AxisAIKey.self] = newValue }
    }

    var axisHealth: AxisHealthClient {
        get { self[AxisHealthKey.self] }
        set { self[AxisHealthKey.self] = newValue }
    }

    var axisNotifications: AxisNotificationsClient {
        get { self[AxisNotificationsKey.self] }
        set { self[AxisNotificationsKey.self] = newValue }
    }
}

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .commandCenter
        var contextMode: ContextMode = .work
        var commandCenter = CommandCenterReducer.State()
        var workSuite = WorkSuiteReducer.State()
        var familyHQ = FamilyHQReducer.State()
        var socialCircle = SocialCircleReducer.State()
        var explore = ExploreReducer.State()
        var balance = BalanceReducer.State()
        var settings = SettingsReducer.State()
        var trends = TrendsReducer.State()
        var showQuickCapture = false
        var showSettings = false
        var showOnboarding = false
        var showTrends = false
        var userName: String = "Runell"

        enum Tab: Int, CaseIterable, Identifiable {
            case commandCenter = 0
            case workSuite = 1
            case familyHQ = 2
            case socialCircle = 3
            case explore = 4
            case balance = 5

            var id: Int { rawValue }

            var title: String {
                switch self {
                case .commandCenter: return "Command"
                case .workSuite: return "Work"
                case .familyHQ: return "Family"
                case .socialCircle: return "Social"
                case .explore: return "Explore"
                case .balance: return "Balance"
                }
            }

            var icon: String {
                switch self {
                case .commandCenter: return "bolt.fill"
                case .workSuite: return "building.columns.fill"
                case .familyHQ: return "house.fill"
                case .socialCircle: return "person.2.fill"
                case .explore: return "safari.fill"
                case .balance: return "heart.fill"
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tabSelected(State.Tab)
        case contextModeChanged(ContextMode)
        case commandCenter(CommandCenterReducer.Action)
        case workSuite(WorkSuiteReducer.Action)
        case familyHQ(FamilyHQReducer.Action)
        case socialCircle(SocialCircleReducer.Action)
        case explore(ExploreReducer.Action)
        case balance(BalanceReducer.Action)
        case settings(SettingsReducer.Action)
        case trends(TrendsReducer.Action)
        case toggleQuickCapture
        case toggleSettings
        case toggleTrends
        case completeOnboarding
    }

    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Scope(state: \.commandCenter, action: \.commandCenter) {
            CommandCenterReducer()
        }
        Scope(state: \.workSuite, action: \.workSuite) {
            WorkSuiteReducer()
        }
        Scope(state: \.familyHQ, action: \.familyHQ) {
            FamilyHQReducer()
        }
        Scope(state: \.socialCircle, action: \.socialCircle) {
            SocialCircleReducer()
        }
        Scope(state: \.explore, action: \.explore) {
            ExploreReducer()
        }
        Scope(state: \.balance, action: \.balance) {
            BalanceReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
        Scope(state: \.trends, action: \.trends) {
            TrendsReducer()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let profile = persistence.getOrCreateProfile()
                state.userName = profile.name
                state.showOnboarding = !profile.onboardingComplete

                // Auto-switch context mode based on time of day
                let hour = Calendar.current.component(.hour, from: Date())
                let workStartHour = Calendar.current.component(.hour, from: profile.workStartTime)
                let workEndHour = Calendar.current.component(.hour, from: profile.workEndTime)

                let autoMode: ContextMode
                if hour < workStartHour {
                    autoMode = .me
                } else if hour < workEndHour {
                    autoMode = .work
                } else {
                    autoMode = .dad
                }
                state.contextMode = autoMode
                state.commandCenter.contextMode = autoMode
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .contextModeChanged(mode):
                state.contextMode = mode
                state.commandCenter.contextMode = mode
                return .none

            case .toggleQuickCapture:
                state.showQuickCapture.toggle()
                return .none

            case .toggleSettings:
                state.showSettings.toggle()
                return .none

            case .toggleTrends:
                state.showTrends.toggle()
                return .none

            case .completeOnboarding:
                state.showOnboarding = false
                state.userName = persistence.getOrCreateProfile().name
                return .none

            case .commandCenter, .workSuite, .familyHQ, .socialCircle, .explore, .balance, .settings, .trends:
                return .none
            }
        }
    }
}
