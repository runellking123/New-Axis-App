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

        // Daily quote
        var dailyQuote: String = ""
        var dailyQuoteAuthor: String = ""
        var dailyQuoteGrandma: String = ""
        var quoteHistory: [QuoteEntry] = []
        var quoteHistoryIndex: Int = -1

        struct QuoteEntry: Equatable {
            var quote: String
            var author: String
            var grandma: String
        }

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
        case quoteLoaded(quote: String, author: String, grandma: String)
        case refreshQuote
        case previousQuote
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

                    // Daily quote
                    let bq = Self.randomBibleQuote()
                    await send(.quoteLoaded(quote: bq.verse, author: bq.reference, grandma: bq.grandmaVersion))
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

            case let .quoteLoaded(quote, author, grandma):
                state.dailyQuote = quote
                state.dailyQuoteAuthor = author
                state.dailyQuoteGrandma = grandma
                state.quoteHistory.append(State.QuoteEntry(quote: quote, author: author, grandma: grandma))
                state.quoteHistoryIndex = state.quoteHistory.count - 1
                return .none

            case .refreshQuote:
                // If we were browsing history, check if there's a forward quote
                if state.quoteHistoryIndex < state.quoteHistory.count - 1 {
                    state.quoteHistoryIndex += 1
                    let entry = state.quoteHistory[state.quoteHistoryIndex]
                    state.dailyQuote = entry.quote
                    state.dailyQuoteAuthor = entry.author
                    state.dailyQuoteGrandma = entry.grandma
                } else {
                    let bq = Self.randomBibleQuote()
                    state.dailyQuote = bq.verse
                    state.dailyQuoteAuthor = bq.reference
                    state.dailyQuoteGrandma = bq.grandmaVersion
                    state.quoteHistory.append(State.QuoteEntry(quote: bq.verse, author: bq.reference, grandma: bq.grandmaVersion))
                    state.quoteHistoryIndex = state.quoteHistory.count - 1
                }
                return .none

            case .previousQuote:
                guard state.quoteHistoryIndex > 0 else { return .none }
                state.quoteHistoryIndex -= 1
                let entry = state.quoteHistory[state.quoteHistoryIndex]
                state.dailyQuote = entry.quote
                state.dailyQuoteAuthor = entry.author
                state.dailyQuoteGrandma = entry.grandma
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

    // MARK: - Quotes

    struct Quote {
        let text: String
        let author: String
    }

    struct BibleQuote {
        let verse: String
        let reference: String
        let grandmaVersion: String
    }

    static func randomQuote() -> Quote {
        let q = randomBibleQuote()
        return Quote(text: q.verse, author: q.reference)
    }

    static func randomBibleQuote() -> BibleQuote {
        let quotes: [BibleQuote] = [
            // Faith & Trust
            BibleQuote(verse: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.", reference: "Jeremiah 29:11", grandmaVersion: "God got a whole blueprint for your life and you out here stressing over chapter 3. Relax. The plot twist is coming and it's in your favor."),
            BibleQuote(verse: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to Him, and He will make your paths straight.", reference: "Proverbs 3:5-6", grandmaVersion: "You think you smart? God is smarter. Get out your own way and watch Him work."),
            BibleQuote(verse: "Be still, and know that I am God.", reference: "Psalm 46:10", grandmaVersion: "You doing too much. Sit your behind down and let God cook. He don't need a sous chef."),
            BibleQuote(verse: "Commit to the Lord whatever you do, and He will establish your plans.", reference: "Proverbs 16:3", grandmaVersion: "Put God on the group chat first. He the only one with a plan that actually works."),
            BibleQuote(verse: "The Lord is my shepherd; I shall not want.", reference: "Psalm 23:1", grandmaVersion: "When God is leading, you ain't lacking. Period. Stop counting what you don't have and look at what He already gave you."),
            BibleQuote(verse: "Cast all your anxiety on Him because He cares for you.", reference: "1 Peter 5:7", grandmaVersion: "Give that worry to God. He's got broader shoulders than you and He don't lose sleep."),

            // Strength & Perseverance
            BibleQuote(verse: "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.", reference: "Isaiah 40:31", grandmaVersion: "You ain't tired, you're reloading. Eagles don't flap with pigeons — get your rest and come back different."),
            BibleQuote(verse: "I can do all things through Christ who strengthens me.", reference: "Philippians 4:13", grandmaVersion: "They said you couldn't? Good. Now go show them what God and a little bit of audacity can do."),
            BibleQuote(verse: "Even though I walk through the valley of the shadow of death, I will fear no evil, for you are with me.", reference: "Psalm 23:4", grandmaVersion: "Dark times don't mean it's over — it means you in the tunnel, not the grave. Keep stepping, you about to see the light."),
            BibleQuote(verse: "God is our refuge and strength, an ever-present help in trouble.", reference: "Psalm 46:1", grandmaVersion: "When the world gets loud, God is the safe house. Run to Him, not from Him."),
            BibleQuote(verse: "The Lord is my light and my salvation — whom shall I fear?", reference: "Psalm 27:1", grandmaVersion: "Fear who? Baby, you walk with the Creator of the universe. Act like it."),
            BibleQuote(verse: "Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.", reference: "Joshua 1:9", grandmaVersion: "Scared? That's natural. But God didn't give you this mission to watch you fail. Square up and move."),
            BibleQuote(verse: "No weapon formed against you shall prosper.", reference: "Isaiah 54:17", grandmaVersion: "They can aim all they want. God already bulletproofed your blessing. Let them waste their ammo."),
            BibleQuote(verse: "When you pass through the waters, I will be with you; and when you pass through the rivers, they will not sweep over you.", reference: "Isaiah 43:2", grandmaVersion: "You're going through it, not drowning in it. There's a difference. God's got the life jacket and He ain't letting go."),
            BibleQuote(verse: "The Lord will fight for you; you need only to be still.", reference: "Exodus 14:14", grandmaVersion: "Some battles ain't yours to fight. Stand back, be quiet, and watch God handle your haters personally."),
            BibleQuote(verse: "I have told you these things, so that in me you may have peace. In this world you will have trouble. But take heart! I have overcome the world.", reference: "John 16:33", grandmaVersion: "Life is gonna life. But the One who made life already beat it. You're on the winning team — act like you got the ring."),

            // Purpose & Destiny
            BibleQuote(verse: "And we know that in all things God works for the good of those who love Him.", reference: "Romans 8:28", grandmaVersion: "That thing that broke you? That's the same thing God's about to use to make you. Stay ready."),
            BibleQuote(verse: "If you have faith as small as a mustard seed, you can say to this mountain, 'Move from here to there,' and it will move.", reference: "Matthew 17:20", grandmaVersion: "You don't need a lot of faith, baby. You just need a little that's real. A real one outweighs a fake hundred every time."),
            BibleQuote(verse: "For we are God's handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.", reference: "Ephesians 2:10", grandmaVersion: "You ain't random. God custom-made you for something specific. Stop trying to be somebody else's copy."),
            BibleQuote(verse: "Before I formed you in the womb I knew you, before you were born I set you apart.", reference: "Jeremiah 1:5", grandmaVersion: "God knew your name before your mama did. You were never an accident — you were always the plan."),
            BibleQuote(verse: "Delight yourself in the Lord, and He will give you the desires of your heart.", reference: "Psalm 37:4", grandmaVersion: "Get close to God and watch your taste level change. The desires He gives you? Those are the ones that actually come through."),
            BibleQuote(verse: "For I am confident of this very thing, that He who began a good work in you will perfect it until the day of Christ Jesus.", reference: "Philippians 1:6", grandmaVersion: "God ain't done with you yet. You're a work in progress, not a finished failure. Give yourself some grace."),
            BibleQuote(verse: "The steps of a good man are ordered by the Lord.", reference: "Psalm 37:23", grandmaVersion: "Even when you feel lost, God got your GPS on. Every step — even the wrong turns — He's rerouting you to the right place."),

            // Wisdom & Words
            BibleQuote(verse: "The tongue has the power of life and death.", reference: "Proverbs 18:21", grandmaVersion: "Fix your mouth. You can't be talking defeat Monday and expecting victory Friday. Speak it like you mean it."),
            BibleQuote(verse: "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you.", reference: "James 1:5", grandmaVersion: "Don't guess — ask God. He ain't stingy with wisdom and He won't make you feel dumb for asking."),
            BibleQuote(verse: "A gentle answer turns away wrath, but a harsh word stirs up anger.", reference: "Proverbs 15:1", grandmaVersion: "Not every argument needs your participation. Sometimes the most powerful thing you can say is nothing at all."),
            BibleQuote(verse: "Guard your heart above all else, for it determines the course of your life.", reference: "Proverbs 4:23", grandmaVersion: "Be careful who you let into your space. Not everybody deserves backstage access to your life."),
            BibleQuote(verse: "Do not be misled: Bad company corrupts good character.", reference: "1 Corinthians 15:33", grandmaVersion: "Show me your friends and I'll show you your future. If they ain't going where you're going, why you riding with them?"),
            BibleQuote(verse: "Iron sharpens iron, and one man sharpens another.", reference: "Proverbs 27:17", grandmaVersion: "Keep people around you that push you up, not hold you down. Real ones make you better, not comfortable."),

            // Joy & Gratitude
            BibleQuote(verse: "Weeping may endure for a night, but joy comes in the morning.", reference: "Psalm 30:5", grandmaVersion: "Cry if you need to, that's fine. But set your alarm — because tomorrow? Tomorrow is your day."),
            BibleQuote(verse: "This is the day the Lord has made; let us rejoice and be glad in it.", reference: "Psalm 118:24", grandmaVersion: "You woke up today. That alone is a flex. Some people didn't get this chance. Now go do something with it."),
            BibleQuote(verse: "Give thanks in all circumstances; for this is God's will for you in Christ Jesus.", reference: "1 Thessalonians 5:18", grandmaVersion: "Even when things are sideways, say thank you. Gratitude is the password to the next level."),
            BibleQuote(verse: "The joy of the Lord is your strength.", reference: "Nehemiah 8:10", grandmaVersion: "Your joy isn't based on your situation — it's based on your God. And He hasn't changed. So why are you tripping?"),
            BibleQuote(verse: "Rejoice always, pray continually, give thanks in all circumstances.", reference: "1 Thessalonians 5:16-18", grandmaVersion: "Stay prayerful, stay grateful, stay joyful. That's the recipe. Your grandmother knew it, her grandmother knew it. Now you know it too."),

            // Provision & Patience
            BibleQuote(verse: "And my God will meet all your needs according to the riches of His glory in Christ Jesus.", reference: "Philippians 4:19", grandmaVersion: "You worried about bills? God owns the cattle on a thousand hills. He's not broke and neither are His children."),
            BibleQuote(verse: "But seek first His kingdom and His righteousness, and all these things will be given to you as well.", reference: "Matthew 6:33", grandmaVersion: "Handle God's business first and watch Him handle yours. It's not a transaction — it's a relationship."),
            BibleQuote(verse: "Wait on the Lord; be of good courage, and He shall strengthen your heart.", reference: "Psalm 27:14", grandmaVersion: "God's delay ain't God's denial. He's not slow — He's strategic. Your blessing needs to marinate before it's ready."),
            BibleQuote(verse: "Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.", reference: "Galatians 6:9", grandmaVersion: "You've been planting seeds and seeing nothing? Keep watering. Harvest season don't care about your timeline — it shows up when it's supposed to."),
            BibleQuote(verse: "Consider it pure joy, my brothers and sisters, whenever you face trials of many kinds, because the testing of your faith produces perseverance.", reference: "James 1:2-3", grandmaVersion: "That pressure you're feeling? It's not punishment — it's prep. Diamonds don't form in comfort. Let the pressure do its work."),
            BibleQuote(verse: "He gives strength to the weary and increases the power of the weak.", reference: "Isaiah 40:29", grandmaVersion: "Running on empty? Good. That's when God shows up with a full tank. Your weakness is just His invitation to show off."),

            // Love & Forgiveness
            BibleQuote(verse: "Love is patient, love is kind. It does not envy, it does not boast, it is not proud.", reference: "1 Corinthians 13:4", grandmaVersion: "Real love ain't loud. It's steady, it's consistent, and it shows up when it's not convenient. Everything else is just performance."),
            BibleQuote(verse: "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.", reference: "Ephesians 4:32", grandmaVersion: "Holding grudges is like drinking poison and expecting the other person to get sick. Let it go so YOU can be free."),
            BibleQuote(verse: "Above all, love each other deeply, because love covers over a multitude of sins.", reference: "1 Peter 4:8", grandmaVersion: "Love hard. Not because people deserve it, but because that's who you are. That's the legacy your people left you."),
            BibleQuote(verse: "Do not judge, or you too will be judged.", reference: "Matthew 7:1", grandmaVersion: "Before you point fingers, check your own hands. Everybody got a story you don't know about."),

            // Identity & Confidence
            BibleQuote(verse: "I praise you because I am fearfully and wonderfully made; your works are wonderful, I know that full well.", reference: "Psalm 139:14", grandmaVersion: "God didn't make you to blend in. You were built different on purpose. Own that."),
            BibleQuote(verse: "So God created mankind in His own image, in the image of God He created them.", reference: "Genesis 1:27", grandmaVersion: "You were made in the image of the Most High. Walk into every room knowing whose you are — not just who you are."),
            BibleQuote(verse: "You are the light of the world. A town built on a hill cannot be hidden.", reference: "Matthew 5:14", grandmaVersion: "Stop dimming your light so other people feel comfortable. You were built to shine. Let them get sunglasses."),
            BibleQuote(verse: "If God is for us, who can be against us?", reference: "Romans 8:31", grandmaVersion: "When God signs off on your life, the haters become irrelevant. Let them talk — they're just narrating your come-up."),
            BibleQuote(verse: "The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you.", reference: "Zephaniah 3:17", grandmaVersion: "God doesn't just tolerate you — He celebrates you. Read that again. The Creator of everything is proud of YOU."),
            BibleQuote(verse: "But you are a chosen people, a royal priesthood, a holy nation, God's special possession.", reference: "1 Peter 2:9", grandmaVersion: "You ain't ordinary. You're chosen, you're royalty, you're set apart. Stop begging for a seat at tables God didn't build for you."),

            // Work & Hustle
            BibleQuote(verse: "Whatever you do, work at it with all your heart, as working for the Lord, not for human masters.", reference: "Colossians 3:23", grandmaVersion: "Don't work for the applause. Work like God is your boss — because He is. Excellence ain't for show, it's for the soul."),
            BibleQuote(verse: "The hand of the diligent will rule, while the slothful will be put to forced labor.", reference: "Proverbs 12:24", grandmaVersion: "Hard work puts you in charge. Laziness puts you under somebody else's thumb. Choose wisely."),
            BibleQuote(verse: "She is clothed with strength and dignity; she can laugh at the days to come.", reference: "Proverbs 31:25", grandmaVersion: "Walk with your head up and your shoulders back. When you're covered by God, the future doesn't scare you — it excites you."),
            BibleQuote(verse: "Lazy hands make for poverty, but diligent hands bring wealth.", reference: "Proverbs 10:4", grandmaVersion: "Ain't nothing gon' fall in your lap but crumbs. Get up, get to work, and go build what God put in your heart."),
            BibleQuote(verse: "Whatever your hand finds to do, do it with your might.", reference: "Ecclesiastes 9:10", grandmaVersion: "Half-doing something is worse than not doing it at all. If you gon' show up, show out. Give it everything or save your energy."),

            // Peace & Rest
            BibleQuote(verse: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.", reference: "John 14:27", grandmaVersion: "The world's peace is temporary — it comes and goes with your Wi-Fi. God's peace? That stays even when everything around you is falling apart."),
            BibleQuote(verse: "Come to me, all you who are weary and burdened, and I will give you rest.", reference: "Matthew 11:28", grandmaVersion: "You been carrying everybody else's bags? Put them down. Jesus didn't say 'come to me, all you who got it together.' He said come as you are."),
            BibleQuote(verse: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.", reference: "Philippians 4:6", grandmaVersion: "Worry is just praying for what you don't want. Flip the script — tell God what you need and then thank Him like it's already done."),
            BibleQuote(verse: "He makes me lie down in green pastures, He leads me beside quiet waters, He refreshes my soul.", reference: "Psalm 23:2-3", grandmaVersion: "Sometimes God makes you rest because you're too stubborn to do it yourself. That setback? That might just be God sitting you down because you needed it."),

            // New Beginnings
            BibleQuote(verse: "Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!", reference: "2 Corinthians 5:17", grandmaVersion: "Your past got a expiration date. God hit the reset button — stop going back to read old chapters. You're in a new book now."),
            BibleQuote(verse: "See, I am doing a new thing! Now it springs up; do you not perceive it?", reference: "Isaiah 43:19", grandmaVersion: "Stop looking in the rearview. God is doing something brand new and you gon' miss it being stuck on what was."),
            BibleQuote(verse: "His mercies are new every morning; great is Your faithfulness.", reference: "Lamentations 3:23", grandmaVersion: "Yesterday's mess doesn't own today. God's grace got a fresh batch waiting for you every single morning. Go get yours."),
            BibleQuote(verse: "Forget the former things; do not dwell on the past.", reference: "Isaiah 43:18", grandmaVersion: "What happened, happened. You can't unscramble eggs. But you can make a whole new breakfast. Move forward."),
        ]
        return quotes.randomElement() ?? BibleQuote(verse: "Be strong and courageous.", reference: "Joshua 1:9", grandmaVersion: "Square up and move. God's got you.")
    }
}
