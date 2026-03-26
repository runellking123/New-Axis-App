import ComposableArchitecture
import Foundation

@Reducer
struct EADashboardReducer {
    @ObservableState
    struct State: Equatable {
        var userName: String = ""
        var currentGreeting: String = "Good morning"
        var weatherTemp: String = "--"
        var weatherIcon: String = "cloud.fill"
        var weatherNote: String = "Loading..."
        var weatherCondition: String = ""
        var weatherFeelsLike: String = ""
        var weatherHumidity: String = ""
        var isWeatherLoaded: Bool = false
        var locationName: String = ""
        var nextEventTitle: String = ""
        var nextEventTime: String = ""
        var energyScore: Int = 0
        var isEnergyLoaded: Bool = false

        // Plan summary
        var planSummary: String = ""
        var planTimeBlocks: [TimeBlockState] = []
        var isPlanLoaded: Bool = false

        // At-risk tasks
        var atRiskTasks: [AtRiskTaskState] = []

        // Next best action
        var nextBestAction: NextBestActionState?

        // Active projects
        var activeProjects: [ProjectSummaryState] = []

        // Inbox
        var inboxCount: Int = 0

        // Upcoming deadlines
        var upcomingDeadlines: [DeadlineState] = []

        // Recent AI chat summary
        var recentChatSummary: String = ""

        // Quick stats
        var tasksCompletedToday: Int = 0
        var meetingsRemaining: Int = 0
        var deepWorkHoursToday: Double = 0

        // Quick add
        var quickAddText: String = ""

        // Streak
        var streakDays: Int = 0

        // Focus mode
        var isFocusMode: Bool = false

        var isLoading: Bool = false

        struct TimeBlockState: Equatable, Identifiable {
            let id = UUID()
            var title: String
            var startTime: String
            var endTime: String
            var blockType: String
        }

        struct AtRiskTaskState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var deadline: Date
            var priority: String
        }

        struct NextBestActionState: Equatable {
            var taskTitle: String
            var taskId: UUID?
            var reasoning: String
        }

        struct ProjectSummaryState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var progress: Double
            var daysToDeadline: Int?
            var category: String
        }

        struct DeadlineState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var deadline: Date
            var daysLeft: Int
            var category: String
        }
    }

    enum Action: Equatable {
        case onAppear
        case refreshTapped
        case weatherLoaded(temp: String, icon: String, note: String, location: String, condition: String, feelsLike: String, humidity: String)
        case energyLoaded(Int)
        case planLoaded(summary: String, blocks: [State.TimeBlockState])
        case atRiskTasksLoaded([State.AtRiskTaskState])
        case nextBestActionLoaded(State.NextBestActionState?)
        case projectsLoaded([State.ProjectSummaryState])
        case statsLoaded(completed: Int, meetings: Int, deepWork: Double)
        case inboxCountLoaded(Int)
        case deadlinesLoaded([State.DeadlineState])
        case chatSummaryLoaded(String)
        case quickAddTextChanged(String)
        case quickAddSubmit
        case streakLoaded(Int)
        case toggleFocusMode
        case navigateToPlanner
        case navigateToTasks
        case scheduleAtRiskTask(UUID)
    }

    @Dependency(\.axisWeather) var weather
    @Dependency(\.axisCalendar) var calendar
    @Dependency(\.axisHealth) var health
    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.currentGreeting = Self.greetingForTimeOfDay()
                state.userName = persistence.getOrCreateProfile().name
                return .run { send in
                    // Request location permission and wait for it to resolve
                    let locService = LocationService.shared
                    await MainActor.run {
                        locService.requestPermission()
                        locService.requestLocation()
                    }

                    // Wait for location to resolve (up to 10 seconds)
                    for _ in 0..<20 {
                        let locationAvailable = await MainActor.run { locService.effectiveLocation != nil }
                        if locationAvailable { break }
                        try? await Task.sleep(for: .milliseconds(500))
                    }

                    // Weather
                    let weatherData = await weather.fetchWeather()
                    if let data = weatherData {
                        let locationName = await MainActor.run {
                            let current = LocationService.shared.currentLocationName
                            return current.isEmpty ? data.location : current
                        }
                        await send(.weatherLoaded(
                            temp: data.temperatureFormatted,
                            icon: data.sfSymbol,
                            note: data.actionableNote,
                            location: locationName,
                            condition: data.condition,
                            feelsLike: "\(Int(data.feelsLike))°",
                            humidity: "\(data.humidity)%"
                        ))
                    } else {
                        let errorMessage = await weather.lastErrorMessage()
                        await send(.weatherLoaded(
                            temp: "--",
                            icon: "cloud.fill",
                            note: errorMessage ?? "Weather unavailable.",
                            location: "",
                            condition: "",
                            feelsLike: "",
                            humidity: ""
                        ))
                    }

                    // Health/Energy
                    let isAuth = await health.isAuthorized()
                    var energyScore = 0
                    if isAuth {
                        let snapshot = await health.fetchAllData()
                        energyScore = snapshot.energy
                        await send(.energyLoaded(snapshot.energy))
                    }

                    // Calendar events for plan + stats — only current/future
                    let calAccess = await calendar.requestAccess()
                    if calAccess {
                        let allEvents = await calendar.fetchTodayEvents()
                        let now = Date()
                        // Only show events that haven't ended yet
                        let upcomingEvents = allEvents.filter { $0.endDate > now && !$0.isAllDay }
                        let remaining = upcomingEvents.count
                        await send(.statsLoaded(completed: 0, meetings: remaining, deepWork: 0))

                        let remAccess = await calendar.requestRemindersAccess()
                        let reminders: [CalendarService.ReminderItem]
                        if remAccess {
                            let incomplete = await calendar.fetchIncompleteReminders()
                            let startOfDay = Calendar.current.startOfDay(for: now)
                            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)
                            reminders = Self.remindersForToday(incomplete, startOfDay: startOfDay, endOfDay: endOfDay)
                        } else {
                            reminders = []
                        }

                        let planBlocks = Self.dashboardTimelineBlocks(
                            events: upcomingEvents,
                            reminders: reminders,
                            now: now
                        )

                        var summaryParts: [String] = []
                        if remaining > 0 { summaryParts.append("\(remaining) upcoming event\(remaining == 1 ? "" : "s")") }
                        if !reminders.isEmpty { summaryParts.append("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")") }
                        let summary = summaryParts.isEmpty
                            ? "Your day is clear — great time for deep work."
                            : summaryParts.joined(separator: ", ") + " today."
                        await send(.planLoaded(summary: summary, blocks: planBlocks))
                    } else {
                        await send(.planLoaded(summary: "Grant calendar access in Settings to see your daily plan.", blocks: []))
                    }

                    let eaTasks = persistence.fetchEATasks()
                    let atRiskTasks = eaTasks.filter(\.isAtRisk).map {
                        State.AtRiskTaskState(
                            id: $0.uuid,
                            title: $0.title,
                            deadline: $0.deadline ?? Date.distantFuture,
                            priority: $0.priority
                        )
                    }
                    await send(.atRiskTasksLoaded(atRiskTasks))

                    let allPersistedTasks = persistence.fetchEATasks()
                    let activeProjects = persistence.fetchEAProjects()
                        .filter { $0.status == "active" }
                        .map { project -> State.ProjectSummaryState in
                            let projectTasks = allPersistedTasks.filter { $0.projectId == project.uuid }
                            let completedCount = projectTasks.filter { $0.status == "completed" }.count
                            let progress = projectTasks.isEmpty ? 0 : Double(completedCount) / Double(projectTasks.count)
                            let daysToDeadline = project.deadline.map {
                                Calendar.current.dateComponents([.day], from: Date(), to: $0).day
                            } ?? nil
                            return State.ProjectSummaryState(
                                id: project.uuid,
                                title: project.title,
                                progress: progress,
                                daysToDeadline: daysToDeadline,
                                category: project.category
                            )
                        }
                    await send(.projectsLoaded(activeProjects))

                    await send(.inboxCountLoaded(persistence.fetchUnreviewedInboxCount()))

                    // Upcoming deadlines (next 7 days)
                    let allTasks = persistence.fetchEATasks()
                    let now = Date()
                    let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now)!
                    let upcoming = allTasks
                        .filter { $0.deadline != nil && $0.deadline! > now && $0.deadline! <= weekFromNow && $0.status != "completed" }
                        .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
                        .prefix(5)
                        .map { task in
                            let days = Calendar.current.dateComponents([.day], from: now, to: task.deadline!).day ?? 0
                            return State.DeadlineState(id: task.uuid, title: task.title, deadline: task.deadline!, daysLeft: days, category: task.category)
                        }
                    await send(.deadlinesLoaded(Array(upcoming)))

                    // Recent AI chat summary
                    let recentThreads = persistence.fetchChatThreads()
                    if let latest = recentThreads.first {
                        let messages = persistence.fetchChatMessages(latest.uuid)
                        if let lastAssistant = messages.last(where: { $0.role == "assistant" }) {
                            let preview = String(lastAssistant.content.prefix(120))
                            await send(.chatSummaryLoaded(preview + (lastAssistant.content.count > 120 ? "..." : "")))
                        }
                    }

                    let nextBest = AIExecutiveService.shared.nextBestAction(tasks: eaTasks, energyScore: energyScore).map {
                        State.NextBestActionState(
                            taskTitle: $0.taskTitle,
                            taskId: $0.taskId,
                            reasoning: $0.reasoning
                        )
                    }
                    await send(.nextBestActionLoaded(nextBest))

                    // Streak calculation
                    let lastOpenKey = "axis_last_open_date"
                    let streakKey = "axis_streak_count"
                    let today = Calendar.current.startOfDay(for: Date())
                    let lastOpen = UserDefaults.standard.object(forKey: lastOpenKey) as? Date
                    let currentStreak = UserDefaults.standard.integer(forKey: streakKey)

                    var newStreak = currentStreak
                    if let lastOpen {
                        let lastDay = Calendar.current.startOfDay(for: lastOpen)
                        let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
                        if daysBetween == 1 {
                            newStreak = currentStreak + 1
                        } else if daysBetween > 1 {
                            newStreak = 1
                        }
                        // daysBetween == 0 means same day, keep current streak
                    } else {
                        newStreak = 1
                    }
                    UserDefaults.standard.set(today, forKey: lastOpenKey)
                    UserDefaults.standard.set(newStreak, forKey: streakKey)
                    await send(.streakLoaded(newStreak))
                }

            case .refreshTapped:
                return .send(.onAppear)

            case let .weatherLoaded(temp, icon, note, location, condition, feelsLike, humidity):
                state.weatherTemp = temp
                state.weatherIcon = icon
                state.weatherNote = note
                state.weatherCondition = condition
                state.weatherFeelsLike = feelsLike
                state.weatherHumidity = humidity
                state.locationName = location
                state.isWeatherLoaded = true
                state.isLoading = false
                return .none

            case let .energyLoaded(score):
                state.energyScore = score
                state.isEnergyLoaded = true
                return .none

            case let .planLoaded(summary, blocks):
                state.planSummary = summary
                state.planTimeBlocks = blocks
                state.isPlanLoaded = true
                return .none

            case let .atRiskTasksLoaded(tasks):
                state.atRiskTasks = tasks
                return .none

            case let .nextBestActionLoaded(action):
                state.nextBestAction = action
                return .none

            case let .projectsLoaded(projects):
                state.activeProjects = projects
                return .none

            case let .statsLoaded(completed, meetings, deepWork):
                state.tasksCompletedToday = completed
                state.meetingsRemaining = meetings
                state.deepWorkHoursToday = deepWork
                return .none

            case let .inboxCountLoaded(count):
                state.inboxCount = count
                return .none

            case let .deadlinesLoaded(deadlines):
                state.upcomingDeadlines = deadlines
                return .none

            case let .chatSummaryLoaded(summary):
                state.recentChatSummary = summary
                return .none

            case let .quickAddTextChanged(text):
                state.quickAddText = text
                return .none

            case .quickAddSubmit:
                let text = state.quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return .none }
                let task = EATask(title: text, status: "inbox", category: "general")
                persistence.saveEATask(task)
                state.quickAddText = ""
                state.inboxCount += 1
                return .none

            case let .streakLoaded(days):
                state.streakDays = days
                return .none

            case .toggleFocusMode:
                state.isFocusMode.toggle()
                return .none

            case .navigateToPlanner, .navigateToTasks:
                return .none

            case .scheduleAtRiskTask:
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

    private static func remindersForToday(
        _ reminders: [CalendarService.ReminderItem],
        startOfDay: Date,
        endOfDay: Date
    ) -> [CalendarService.ReminderItem] {
        var seenTitles = Set<String>()
        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDate, dueDate >= startOfDay, dueDate < endOfDay, !reminder.isCompleted else { return false }
            let normalized = reminder.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seenTitles.contains(normalized) else { return false }
            seenTitles.insert(normalized)
            return true
        }
        .sorted {
            let lhs = $0.dueDate ?? .distantFuture
            let rhs = $1.dueDate ?? .distantFuture
            if lhs != rhs { return lhs < rhs }
            return $0.priority > $1.priority
        }
    }

    private static func dashboardTimelineBlocks(
        events: [CalendarService.CalendarEvent],
        reminders: [CalendarService.ReminderItem],
        now: Date
    ) -> [State.TimeBlockState] {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var blocks = events.map {
            State.TimeBlockState(
                title: $0.title,
                startTime: formatter.string(from: $0.startDate),
                endTime: formatter.string(from: $0.endDate),
                blockType: "meeting"
            )
        }

        let untimedStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        var fallbackTime = max(now, untimedStart)

        for reminder in reminders {
            let start: Date
            let end: Date
            if reminder.hasDueTime, let dueDate = reminder.dueDate {
                start = max(now, dueDate.addingTimeInterval(-30 * 60))
                end = max(start.addingTimeInterval(30 * 60), dueDate)
            } else {
                start = fallbackTime
                end = start.addingTimeInterval(25 * 60)
                fallbackTime = end.addingTimeInterval(5 * 60)
            }

            blocks.append(
                State.TimeBlockState(
                    title: reminder.title,
                    startTime: formatter.string(from: start),
                    endTime: formatter.string(from: end),
                    blockType: "task"
                )
            )
        }

        return blocks.sorted { lhs, rhs in
            let leftDate = formatter.date(from: lhs.startTime) ?? .distantFuture
            let rightDate = formatter.date(from: rhs.startTime) ?? .distantFuture
            return leftDate < rightDate
        }
    }
}
