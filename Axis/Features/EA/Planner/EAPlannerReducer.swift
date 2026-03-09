import ComposableArchitecture
import Foundation

@Reducer
struct EAPlannerReducer {
    @ObservableState
    struct State: Equatable {
        var selectedView: PlanView = .day
        var dailyPlan: DailyPlanState?
        var isGenerating: Bool = false
        var isPlanStale: Bool = false
        var weekDaySummaries: [WeekDaySummary] = []
        var selectedDate: Date = Date()
        var showAddBlock = false
        var newBlockTitle = ""
        var newBlockType = "task"
        var newBlockStart = Date()
        var newBlockEnd = Date().addingTimeInterval(1800)

        enum PlanView: String, CaseIterable, Equatable {
            case day = "Day"
            case week = "Week"
        }

        struct DailyPlanState: Equatable {
            var summary: String
            var timeBlocks: [TimeBlockState]
            var generatedAt: Date
        }

        struct TimeBlockState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var startTime: Date
            var endTime: Date
            var blockType: String // "meeting", "task", "focusBlock", "break", "reminder"
            var taskId: UUID?
            var eventId: String?
            var aiReasoning: String?
            var location: String?

            var durationMinutes: Int {
                Int(endTime.timeIntervalSince(startTime) / 60)
            }

            var blockColor: String {
                switch blockType {
                case "task": return "axisGold"
                case "meeting": return "purple"
                case "focusBlock": return "blue"
                case "break": return "green"
                case "reminder": return "orange"
                default: return "gray"
                }
            }
        }

        struct WeekDaySummary: Equatable, Identifiable {
            let id: Date
            var date: Date
            var eventCount: Int
            var taskCount: Int
            var totalMinutes: Int
        }
    }

    enum Action: Equatable {
        case onAppear
        case generatePlan
        case replan
        case planGenerated(State.DailyPlanState)
        case tapBlock(UUID)
        case switchView(State.PlanView)
        case selectDate(Date)
        case weekSummariesLoaded([State.WeekDaySummary])
        case showAddBlockSheet
        case dismissAddBlockSheet
        case newBlockTitleChanged(String)
        case newBlockTypeChanged(String)
        case newBlockStartChanged(Date)
        case newBlockEndChanged(Date)
        case confirmAddBlock
    }

    @Dependency(\.axisCalendar) var calendar
    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.dailyPlan == nil {
                    return .send(.generatePlan)
                }
                if let plan = state.dailyPlan {
                    state.isPlanStale = abs(plan.generatedAt.timeIntervalSinceNow) > 3 * 3600
                }
                if state.selectedView == .week && state.weekDaySummaries.isEmpty {
                    return .send(.switchView(.week))
                }
                return .none

            case .generatePlan:
                state.isGenerating = true
                let selectedDate = state.selectedDate
                return .run { send in
                    if let savedPlan = persistence.fetchEADailyPlan(selectedDate), !savedPlan.isStale {
                        let savedBlocks = persistence.fetchEATimeBlocks(savedPlan.uuid).map(Self.timeBlockState(from:))
                        let restoredPlan = State.DailyPlanState(
                            summary: savedPlan.aiSummary ?? "Your day is clear — great time for deep work.",
                            timeBlocks: savedBlocks,
                            generatedAt: savedPlan.generatedAt
                        )
                        await send(.planGenerated(restoredPlan))
                        return
                    }

                    let now = Date()
                    let calendarDay = Calendar.current
                    let selectedDayStart = calendarDay.startOfDay(for: selectedDate)
                    let selectedDayEnd = calendarDay.date(byAdding: .day, value: 1, to: selectedDayStart) ?? selectedDayStart.addingTimeInterval(86400)
                    let isToday = calendarDay.isDateInToday(selectedDate)

                    // Fetch calendar events
                    let calAccess = await calendar.requestAccess()
                    var events: [CalendarService.CalendarEvent] = []
                    if calAccess {
                        let allEvents = isToday ? await calendar.fetchTodayEvents() : calendar.fetchEvents(selectedDayStart, selectedDayEnd)
                        events = allEvents.filter { event in
                            event.endDate > now && !event.isAllDay && event.startDate < selectedDayEnd && event.endDate > selectedDayStart
                        }
                    }

                    // Fetch reminders
                    let remAccess = await calendar.requestRemindersAccess()
                    let reminders: [CalendarService.ReminderItem]
                    if remAccess {
                        let incomplete = await calendar.fetchIncompleteReminders()
                        reminders = Self.remindersForDay(
                            incomplete,
                            dayStart: selectedDayStart,
                            dayEnd: selectedDayEnd
                        )
                    } else {
                        reminders = []
                    }

                    let blocks = Self.buildTimelineBlocks(
                        events: events,
                        reminders: reminders,
                        dayStart: selectedDayStart,
                        dayEnd: selectedDayEnd,
                        now: now,
                        isToday: isToday
                    )

                    // Build summary
                    let eventCount = blocks.filter { $0.blockType == "meeting" }.count
                    let reminderCount = reminders.count
                    let summary: String
                    if eventCount == 0 && reminderCount == 0 {
                        summary = "Your day is clear — great time for deep work."
                    } else if isToday {
                        summary = "\(eventCount) upcoming event\(eventCount == 1 ? "" : "s"), \(reminderCount) reminder\(reminderCount == 1 ? "" : "s") today."
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMM d"
                        summary = "\(eventCount) upcoming event\(eventCount == 1 ? "" : "s"), \(reminderCount) reminder\(reminderCount == 1 ? "" : "s") on \(formatter.string(from: selectedDate))."
                    }

                    let plan = State.DailyPlanState(
                        summary: summary,
                        timeBlocks: blocks,
                        generatedAt: Date()
                    )

                    if let existingPlan = persistence.fetchEADailyPlan(selectedDate) {
                        persistence.fetchEATimeBlocks(existingPlan.uuid).forEach { persistence.deleteEATimeBlock($0) }
                        persistence.deleteEADailyPlan(existingPlan)
                    }

                    let planModel = EADailyPlan(date: selectedDate, aiSummary: summary)
                    planModel.generatedAt = plan.generatedAt
                    persistence.saveEADailyPlan(planModel)
                    for block in blocks {
                        let timeBlock = EATimeBlock(
                            startTime: block.startTime,
                            endTime: block.endTime,
                            blockType: block.blockType,
                            taskId: block.taskId,
                            eventId: block.eventId,
                            title: block.title,
                            aiReasoning: block.aiReasoning,
                            planId: planModel.uuid
                        )
                        timeBlock.uuid = block.id
                        persistence.saveEATimeBlock(timeBlock)
                    }

                    await send(.planGenerated(plan))
                }

            case .replan:
                state.dailyPlan = nil
                return .send(.generatePlan)

            case .showAddBlockSheet:
                state.showAddBlock = true
                state.newBlockTitle = ""
                state.newBlockType = "task"
                let dayStart = Calendar.current.startOfDay(for: state.selectedDate)
                let defaultStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart
                state.newBlockStart = defaultStart
                state.newBlockEnd = defaultStart.addingTimeInterval(1800)
                return .none

            case .dismissAddBlockSheet:
                state.showAddBlock = false
                return .none

            case let .newBlockTitleChanged(title):
                state.newBlockTitle = title
                return .none

            case let .newBlockTypeChanged(type):
                state.newBlockType = type
                return .none

            case let .newBlockStartChanged(start):
                state.newBlockStart = start
                if state.newBlockEnd <= start {
                    state.newBlockEnd = start.addingTimeInterval(1800)
                }
                return .none

            case let .newBlockEndChanged(end):
                state.newBlockEnd = end
                return .none

            case .confirmAddBlock:
                let title = state.newBlockTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return .none }
                let endTime = state.newBlockEnd > state.newBlockStart
                    ? state.newBlockEnd
                    : state.newBlockStart.addingTimeInterval(1800)
                let newBlock = State.TimeBlockState(
                    id: UUID(),
                    title: title,
                    startTime: state.newBlockStart,
                    endTime: endTime,
                    blockType: state.newBlockType,
                    taskId: nil,
                    eventId: nil,
                    aiReasoning: "Added manually",
                    location: nil
                )
                if state.dailyPlan == nil {
                    state.dailyPlan = State.DailyPlanState(
                        summary: "Manual plan for \(Self.formatDate(state.selectedDate)).",
                        timeBlocks: [newBlock],
                        generatedAt: Date()
                    )
                } else {
                    state.dailyPlan?.timeBlocks.append(newBlock)
                    state.dailyPlan?.timeBlocks.sort { $0.startTime < $1.startTime }
                    state.dailyPlan?.generatedAt = Date()
                }
                state.showAddBlock = false

                let planModel = persistence.fetchEADailyPlan(state.selectedDate) ?? {
                    let model = EADailyPlan(
                        date: Calendar.current.startOfDay(for: state.selectedDate),
                        aiSummary: state.dailyPlan?.summary
                    )
                    persistence.saveEADailyPlan(model)
                    return model
                }()
                planModel.aiSummary = state.dailyPlan?.summary
                planModel.generatedAt = Date()

                let timeBlock = EATimeBlock(
                    startTime: state.newBlockStart,
                    endTime: endTime,
                    blockType: state.newBlockType,
                    taskId: nil,
                    eventId: nil,
                    title: title,
                    aiReasoning: "Added manually",
                    planId: planModel.uuid
                )
                timeBlock.uuid = newBlock.id
                persistence.saveEATimeBlock(timeBlock)
                return .none

            case let .planGenerated(plan):
                state.dailyPlan = plan
                state.isGenerating = false
                state.isPlanStale = false
                return .none

            case .tapBlock:
                return .none

            case let .switchView(view):
                state.selectedView = view
                if view == .week && state.weekDaySummaries.isEmpty {
                    return .run { send in
                        let calAccess = await calendar.requestAccess()
                        guard calAccess else {
                            await send(.weekSummariesLoaded([]))
                            return
                        }
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        var summaries: [State.WeekDaySummary] = []
                        let remindersAccess = await calendar.requestRemindersAccess()
                        let allIncompleteReminders = remindersAccess ? await calendar.fetchIncompleteReminders() : []

                        for offset in 0..<7 {
                            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                                  let dayEnd = cal.date(byAdding: .day, value: 1, to: day) else { continue }
                            let events = calendar.fetchEvents(day, dayEnd)
                            let now = Date()
                            let timedEvents = events.filter { $0.endDate > now && !$0.isAllDay }
                            let reminderTitles = Set(
                                allIncompleteReminders.compactMap { reminder -> String? in
                                    guard !reminder.isCompleted else { return nil }
                                    guard let dueDate = reminder.dueDate, dueDate >= day && dueDate < dayEnd else { return nil }
                                    let normalized = reminder.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    return normalized.isEmpty ? nil : normalized
                                }
                            )
                            summaries.append(State.WeekDaySummary(
                                id: day,
                                date: day,
                                eventCount: timedEvents.count,
                                taskCount: reminderTitles.count,
                                totalMinutes: timedEvents.reduce(0) { $0 + Int($1.duration / 60) }
                            ))
                        }
                        await send(.weekSummariesLoaded(summaries))
                    }
                }
                return .none

            case let .selectDate(date):
                state.selectedDate = date
                state.selectedView = .day
                state.dailyPlan = nil
                return .send(.generatePlan)

            case let .weekSummariesLoaded(summaries):
                state.weekDaySummaries = summaries
                return .none
            }
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func remindersForDay(
        _ reminders: [CalendarService.ReminderItem],
        dayStart: Date,
        dayEnd: Date
    ) -> [CalendarService.ReminderItem] {
        var seenTitles = Set<String>()
        return reminders.filter { reminder in
            guard !reminder.isCompleted else { return false }
            guard let dueDate = reminder.dueDate, dueDate >= dayStart, dueDate < dayEnd else { return false }
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

    private static func buildTimelineBlocks(
        events: [CalendarService.CalendarEvent],
        reminders: [CalendarService.ReminderItem],
        dayStart: Date,
        dayEnd: Date,
        now: Date,
        isToday: Bool
    ) -> [State.TimeBlockState] {
        var blocks = events.map { event in
            State.TimeBlockState(
                id: UUID(),
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                blockType: "meeting",
                taskId: nil,
                eventId: event.id,
                aiReasoning: nil,
                location: event.location
            )
        }

        for reminder in reminders {
            let duration: TimeInterval = reminder.hasDueTime ? 30 * 60 : 25 * 60
            let startTime: Date
            let endTime: Date

            if reminder.hasDueTime, let dueDate = reminder.dueDate {
                let proposedStart = max(dayStart, dueDate.addingTimeInterval(-duration))
                let proposedEnd = max(proposedStart.addingTimeInterval(duration), dueDate)
                let resolved = nextAvailableSlot(
                    preferredStart: proposedStart,
                    duration: proposedEnd.timeIntervalSince(proposedStart),
                    existingBlocks: blocks,
                    dayEnd: dayEnd
                )
                startTime = resolved.start
                endTime = resolved.end
            } else {
                let baseStart = firstOpenSlotStart(
                    dayStart: dayStart,
                    now: now,
                    isToday: isToday,
                    existingBlocks: blocks
                )
                let resolved = nextAvailableSlot(
                    preferredStart: baseStart,
                    duration: duration,
                    existingBlocks: blocks,
                    dayEnd: dayEnd
                )
                startTime = resolved.start
                endTime = resolved.end
            }

            guard startTime < dayEnd, endTime <= dayEnd else { continue }

            blocks.append(
                State.TimeBlockState(
                    id: UUID(),
                    title: reminder.title,
                    startTime: startTime,
                    endTime: endTime,
                    blockType: "reminder",
                    taskId: nil,
                    eventId: nil,
                    aiReasoning: reminder.dueDate.map { dueDate in
                        reminder.hasDueTime
                            ? "Reminder due \(formatDate(dueDate))."
                            : "Reminder due today."
                    },
                    location: reminder.calendarTitle
                )
            )
            blocks.sort { $0.startTime < $1.startTime }
        }

        return blocks.sorted { $0.startTime < $1.startTime }
    }

    private static func firstOpenSlotStart(
        dayStart: Date,
        now: Date,
        isToday: Bool,
        existingBlocks: [State.TimeBlockState]
    ) -> Date {
        let startBase = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        let candidate = isToday ? max(startBase, roundedUpToQuarterHour(now)) : startBase
        return nextAvailableSlot(
            preferredStart: candidate,
            duration: 25 * 60,
            existingBlocks: existingBlocks,
            dayEnd: Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        ).start
    }

    private static func nextAvailableSlot(
        preferredStart: Date,
        duration: TimeInterval,
        existingBlocks: [State.TimeBlockState],
        dayEnd: Date
    ) -> (start: Date, end: Date) {
        var start = preferredStart
        var end = start.addingTimeInterval(duration)

        for block in existingBlocks.sorted(by: { $0.startTime < $1.startTime }) {
            if end <= block.startTime { break }
            if start < block.endTime && end > block.startTime {
                start = roundedUpToQuarterHour(block.endTime.addingTimeInterval(5 * 60))
                end = start.addingTimeInterval(duration)
            }
        }

        if end > dayEnd {
            start = max(preferredStart, dayEnd.addingTimeInterval(-duration))
            end = start.addingTimeInterval(duration)
        }

        return (start, end)
    }

    private static func roundedUpToQuarterHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let remainder = minute % 15
        let adjustment = remainder == 0 ? 0 : 15 - remainder
        let rounded = calendar.date(byAdding: .minute, value: adjustment, to: date) ?? date
        return calendar.date(bySetting: .second, value: 0, of: rounded) ?? rounded
    }

    private static func timeBlockState(from model: EATimeBlock) -> State.TimeBlockState {
        State.TimeBlockState(
            id: model.uuid,
            title: model.title ?? "Untitled",
            startTime: model.startTime,
            endTime: model.endTime,
            blockType: model.blockType,
            taskId: model.taskId,
            eventId: model.eventId,
            aiReasoning: model.aiReasoning,
            location: nil
        )
    }
}
