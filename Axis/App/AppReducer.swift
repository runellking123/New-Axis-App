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
    var fetchEATasks: @Sendable () -> [EATask]
    var saveEATask: @Sendable (EATask) -> Void
    var deleteEATaskById: @Sendable (UUID) -> Void
    var updateEATasks: @Sendable () -> Void
    var fetchEAProjects: @Sendable () -> [EAProject]
    var saveEAProject: @Sendable (EAProject) -> Void
    var deleteEAProjectById: @Sendable (UUID) -> Void
    var updateEAProjects: @Sendable () -> Void
    var fetchEAMilestones: @Sendable (UUID) -> [EAMilestone]
    var saveEAMilestone: @Sendable (EAMilestone) -> Void
    var fetchEAInboxItems: @Sendable () -> [EAInboxItem]
    var saveEAInboxItem: @Sendable (EAInboxItem) -> Void
    var fetchUnreviewedInboxCount: @Sendable () -> Int
    var fetchEADailyPlan: @Sendable (Date) -> EADailyPlan?
    var saveEADailyPlan: @Sendable (EADailyPlan) -> Void
    var deleteEADailyPlan: @Sendable (EADailyPlan) -> Void
    var fetchEATimeBlocks: @Sendable (UUID) -> [EATimeBlock]
    var saveEATimeBlock: @Sendable (EATimeBlock) -> Void
    var deleteEATimeBlock: @Sendable (EATimeBlock) -> Void
    var fetchChatMessages: @Sendable (UUID?) -> [ChatMessage]
    var saveChatMessage: @Sendable (ChatMessage) -> Void
    var deleteChatMessage: @Sendable (UUID) -> Void
    var fetchChatThreads: @Sendable () -> [ChatThread]
    var saveChatThread: @Sendable (ChatThread) -> Void
    var deleteChatThread: @Sendable (UUID) -> Void
    var updateChatThreadTimestamp: @Sendable (UUID) -> Void
    var fetchNotes: @Sendable () -> [CapturedNote]
    var saveNote: @Sendable (CapturedNote) -> Void
    var deleteNote: @Sendable (CapturedNote) -> Void
    var updateNotes: @Sendable () -> Void
}

struct AxisHapticsClient {
    var modeSwitch: @Sendable () -> Void
    var celebration: @Sendable () -> Void
    var notificationSuccess: @Sendable () -> Void
    var selection: @Sendable () -> Void
}

struct AxisWeatherClient {
    var fetchWeather: @Sendable () async -> WeatherService.WeatherData?
    var lastErrorMessage: @Sendable () async -> String?
}

struct AxisCalendarClient {
    var requestAccess: @Sendable () async -> Bool
    var fetchTodayEvents: @Sendable () async -> [CalendarService.CalendarEvent]
    var upcomingEvent: @Sendable () -> CalendarService.CalendarEvent?
    var requestRemindersAccess: @Sendable () async -> Bool
    var fetchTodayReminders: @Sendable () async -> [CalendarService.ReminderItem]
    var fetchIncompleteReminders: @Sendable () async -> [CalendarService.ReminderItem]
    var completeReminder: @Sendable (String) -> Bool
    var createTimeBlock: @Sendable (String, Date, Date, String?) -> String?
    var fetchEvents: @Sendable (Date, Date) -> [CalendarService.CalendarEvent]
}

struct AxisAIClient {
    var generateDayBriefSummary: @Sendable ([CalendarService.CalendarEvent], [PriorityItem], WeatherService.WeatherData?) -> String
    var generateWeeklyReport: @Sendable (Int) -> AIService.WeeklyReport
}

struct AxisHealthClient {
    var isAuthorized: @Sendable () async -> Bool
    var isAvailable: @Sendable () async -> Bool
    var requestAuthorization: @Sendable () async -> Bool
    var fetchAllData: @Sendable () async -> (sleep: Double, steps: Int, energy: Int, calories: Int, heartRate: Double, standHours: Int)
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
        updateUserProfile: { PersistenceService.shared.updateUserProfile() },
        fetchEATasks: { PersistenceService.shared.fetchEATasks() },
        saveEATask: { PersistenceService.shared.saveEATask($0) },
        deleteEATaskById: { id in
            let tasks = PersistenceService.shared.fetchEATasks()
            if let task = tasks.first(where: { $0.uuid == id }) {
                PersistenceService.shared.deleteEATask(task)
            }
        },
        updateEATasks: { PersistenceService.shared.updateEATasks() },
        fetchEAProjects: { PersistenceService.shared.fetchEAProjects() },
        saveEAProject: { PersistenceService.shared.saveEAProject($0) },
        deleteEAProjectById: { id in
            let projects = PersistenceService.shared.fetchEAProjects()
            if let project = projects.first(where: { $0.uuid == id }) {
                PersistenceService.shared.deleteEAProject(project)
            }
        },
        updateEAProjects: { PersistenceService.shared.updateEAProjects() },
        fetchEAMilestones: { PersistenceService.shared.fetchEAMilestones(forProject: $0) },
        saveEAMilestone: { PersistenceService.shared.saveEAMilestone($0) },
        fetchEAInboxItems: { PersistenceService.shared.fetchEAInboxItems() },
        saveEAInboxItem: { PersistenceService.shared.saveEAInboxItem($0) },
        fetchUnreviewedInboxCount: { PersistenceService.shared.fetchUnreviewedEAInboxItems().count },
        fetchEADailyPlan: { PersistenceService.shared.fetchEADailyPlan(for: $0) },
        saveEADailyPlan: { PersistenceService.shared.saveEADailyPlan($0) },
        deleteEADailyPlan: { PersistenceService.shared.deleteEADailyPlan($0) },
        fetchEATimeBlocks: { PersistenceService.shared.fetchEATimeBlocks(forPlan: $0) },
        saveEATimeBlock: { PersistenceService.shared.saveEATimeBlock($0) },
        deleteEATimeBlock: { PersistenceService.shared.deleteEATimeBlock($0) },
        fetchChatMessages: { threadId in
            PersistenceService.shared.fetchChatMessages(threadId: threadId)
        },
        saveChatMessage: { msg in
            PersistenceService.shared.saveChatMessage(msg)
        },
        deleteChatMessage: { id in
            PersistenceService.shared.deleteChatMessage(id)
        },
        fetchChatThreads: {
            PersistenceService.shared.fetchChatThreads()
        },
        saveChatThread: { thread in
            PersistenceService.shared.saveChatThread(thread)
        },
        deleteChatThread: { id in
            PersistenceService.shared.deleteChatThread(id)
        },
        updateChatThreadTimestamp: { id in
            PersistenceService.shared.updateChatThreadTimestamp(id)
        },
        fetchNotes: {
            PersistenceService.shared.fetchCapturedNotes()
        },
        saveNote: { note in
            PersistenceService.shared.saveCapturedNote(note)
        },
        deleteNote: { note in
            PersistenceService.shared.deleteCapturedNote(note)
        },
        updateNotes: {
            PersistenceService.shared.updateCapturedNotes()
        }
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
            let weather = WeatherService.shared
            return await weather.fetchWeather()
        },
        lastErrorMessage: {
            await MainActor.run { WeatherService.shared.lastErrorMessage }
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
        upcomingEvent: { CalendarService.shared.upcomingEvent() },
        requestRemindersAccess: { await CalendarService.shared.requestRemindersAccess() },
        fetchTodayReminders: { await CalendarService.shared.fetchTodayReminders() },
        fetchIncompleteReminders: { await CalendarService.shared.fetchIncompleteReminders() },
        completeReminder: { id in CalendarService.shared.completeReminder(id: id) },
        createTimeBlock: { title, start, end, notes in CalendarService.shared.createTimeBlock(title: title, start: start, end: end, notes: notes) },
        fetchEvents: { start, end in CalendarService.shared.fetchEvents(start: start, end: end) }
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
            return await MainActor.run { (hk.sleepHours, hk.stepsToday, hk.energyScore, hk.activeCalories, hk.heartRate, hk.standHours) }
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
        var selectedTab: Tab = .dashboard
        var contextMode: ContextMode = .work

        // EA tabs (new)
        var eaDashboard = EADashboardReducer.State()
        var eaPlanner = EAPlannerReducer.State()
        var eaTasks = EATaskReducer.State()
        var eaProjects = EAProjectReducer.State()

        // Preserved tabs
        var socialCircle = SocialCircleReducer.State()
        var familyHQ = FamilyHQReducer.State()
        var explore = ExploreReducer.State()
        var balance = BalanceReducer.State()
        var trends = TrendsReducer.State()
        var aiChat = AIChatReducer.State()
        var budget = BudgetReducer.State()
        var quickNotes = QuickNotesReducer.State()
        var voiceMemos = VoiceMemosReducer.State()
        var travelPlanner = TravelPlannerReducer.State()
        var clipboard = ClipboardReducer.State()
        var settings = SettingsReducer.State()

        // Legacy (kept for data but not primary tabs)
        var commandCenter = CommandCenterReducer.State()
        var workSuite = WorkSuiteReducer.State()

        var showQuickCapture = false
        var showSettings = false
        var showOnboarding = false
        var showTrends = false
        var userName: String = ""

        enum Tab: Int, CaseIterable, Identifiable {
            // Primary tabs (visible in tab bar)
            case dashboard = 0
            case calendar = 1
            case aiChat = 2
            case notes = 3
            case tasks = 4
            // Under More
            case explore = 5
            case planner = 6
            case projects = 7
            case social = 8
            case familyHQ = 9
            case balance = 10
            case budget = 11
            case trends = 12
            case voiceMemos = 13
            case travel = 14
            case clipboard = 15
            case settings = 16

            var id: Int { rawValue }

            var title: String {
                switch self {
                case .dashboard: return "Dashboard"
                case .calendar: return "Calendar"
                case .aiChat: return "AI Chat"
                case .explore: return "Explore"
                case .tasks: return "Tasks"
                case .planner: return "Planner"
                case .projects: return "Projects"
                case .social: return "Social"
                case .familyHQ: return "FamilyHQ"
                case .balance: return "Balance"
                case .budget: return "Budget"
                case .trends: return "News"
                case .notes: return "Notes"
                case .voiceMemos: return "Voice Memos"
                case .travel: return "Travel"
                case .clipboard: return "Clipboard"
                case .settings: return "Settings"
                }
            }

            var icon: String {
                switch self {
                case .dashboard: return "house.fill"
                case .calendar: return "calendar"
                case .aiChat: return "bubble.left.and.text.bubble.right"
                case .explore: return "map.fill"
                case .tasks: return "checklist"
                case .planner: return "calendar.badge.clock"
                case .projects: return "folder.fill"
                case .social: return "person.2.fill"
                case .familyHQ: return "house.and.flag.fill"
                case .balance: return "heart.circle.fill"
                case .budget: return "dollarsign.circle.fill"
                case .trends: return "newspaper.fill"
                case .notes: return "note.text"
                case .voiceMemos: return "mic.fill"
                case .travel: return "airplane"
                case .clipboard: return "doc.on.clipboard"
                case .settings: return "gearshape.fill"
                }
            }

            var isPrimary: Bool {
                switch self {
                case .dashboard, .calendar, .aiChat, .notes, .tasks: return true
                default: return false
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tabSelected(State.Tab)
        case contextModeChanged(ContextMode)

        // EA actions
        case eaDashboard(EADashboardReducer.Action)
        case eaPlanner(EAPlannerReducer.Action)
        case eaTasks(EATaskReducer.Action)
        case eaProjects(EAProjectReducer.Action)

        // Preserved tab actions
        case socialCircle(SocialCircleReducer.Action)
        case familyHQ(FamilyHQReducer.Action)
        case explore(ExploreReducer.Action)
        case balance(BalanceReducer.Action)
        case budget(BudgetReducer.Action)
        case quickNotes(QuickNotesReducer.Action)
        case voiceMemos(VoiceMemosReducer.Action)
        case travelPlanner(TravelPlannerReducer.Action)
        case clipboard(ClipboardReducer.Action)
        case trends(TrendsReducer.Action)
        case aiChat(AIChatReducer.Action)
        case settings(SettingsReducer.Action)

        // Legacy
        case commandCenter(CommandCenterReducer.Action)
        case workSuite(WorkSuiteReducer.Action)

        case toggleQuickCapture
        case toggleSettings
        case toggleTrends
        case completeOnboarding
        case handleDeepLink(URL)
    }

    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        // EA reducers
        Scope(state: \.eaDashboard, action: \.eaDashboard) {
            EADashboardReducer()
        }
        Scope(state: \.eaPlanner, action: \.eaPlanner) {
            EAPlannerReducer()
        }
        Scope(state: \.eaTasks, action: \.eaTasks) {
            EATaskReducer()
        }
        Scope(state: \.eaProjects, action: \.eaProjects) {
            EAProjectReducer()
        }

        // Preserved reducers
        Scope(state: \.socialCircle, action: \.socialCircle) {
            SocialCircleReducer()
        }
        Scope(state: \.familyHQ, action: \.familyHQ) {
            FamilyHQReducer()
        }
        Scope(state: \.explore, action: \.explore) {
            ExploreReducer()
        }
        Scope(state: \.balance, action: \.balance) {
            BalanceReducer()
        }
        Scope(state: \.budget, action: \.budget) {
            BudgetReducer()
        }
        Scope(state: \.quickNotes, action: \.quickNotes) {
            QuickNotesReducer()
        }
        Scope(state: \.voiceMemos, action: \.voiceMemos) {
            VoiceMemosReducer()
        }
        Scope(state: \.travelPlanner, action: \.travelPlanner) {
            TravelPlannerReducer()
        }
        Scope(state: \.clipboard, action: \.clipboard) {
            ClipboardReducer()
        }
        Scope(state: \.trends, action: \.trends) {
            TrendsReducer()
        }
        Scope(state: \.aiChat, action: \.aiChat) {
            AIChatReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }

        // Legacy (kept for migration)
        Scope(state: \.commandCenter, action: \.commandCenter) {
            CommandCenterReducer()
        }
        Scope(state: \.workSuite, action: \.workSuite) {
            WorkSuiteReducer()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                let profile = persistence.getOrCreateProfile()
                state.userName = profile.name
                state.showOnboarding = !profile.onboardingComplete

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
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                if tab == .planner {
                    state.eaPlanner.selectedView = .day
                    state.eaPlanner.selectedDate = Date()
                    state.eaPlanner.dailyPlan = nil
                    state.eaPlanner.isPlanStale = false
                }
                return .none

            case let .contextModeChanged(mode):
                state.contextMode = mode
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

            case let .handleDeepLink(url):
                guard url.scheme == "axis" else { return .none }
                switch url.host {
                case "planner": state.selectedTab = .planner
                case "tasks": state.selectedTab = .tasks
                case "projects": state.selectedTab = .projects
                case "dashboard": state.selectedTab = .dashboard
                case "calendar": state.selectedTab = .calendar
                case "notes": state.selectedTab = .notes
                case "voice-memos", "memo": state.selectedTab = .voiceMemos
                case "travel": state.selectedTab = .travel
                case "chat": state.selectedTab = .aiChat
                case "note": state.selectedTab = .notes
                case "meal":
                    state.selectedTab = .familyHQ
                    state.familyHQ.selectedSection = .meals
                default: break
                }
                return .none

            case .eaDashboard, .eaPlanner, .eaTasks, .eaProjects,
                 .socialCircle, .familyHQ, .explore, .balance, .budget, .quickNotes, .voiceMemos, .travelPlanner, .clipboard, .trends, .aiChat, .settings,
                 .commandCenter, .workSuite:
                return .none
            }
        }
    }
}
