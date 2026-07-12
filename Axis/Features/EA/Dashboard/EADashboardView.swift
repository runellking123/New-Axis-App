import ComposableArchitecture
import SwiftUI

// MARK: - EA Dashboard · The Private Bank Treatment
//
// A daily briefing prepared for the principal, not a feed of widgets.
// Three time-of-day registers (morning / midday / evening) share the same
// chrome and content surfaces; only the hero copy and palette morph.

struct EADashboardView: View {
    @Bindable var store: StoreOf<EADashboardReducer>
    var onNavigateToPlanner: (() -> Void)?
    var onNavigateToTasks: (() -> Void)?
    var onNavigateToProjects: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onAddTapped: (() -> Void)?
    var onCompletedTasksTapped: (() -> Void)?
    var onMeetingsTapped: (() -> Void)?
    var onDeepWorkTapped: (() -> Void)?
    var onToggleDarkMode: (() -> Void)?
    var isDarkMode: Bool = false

    @State private var showWeatherDetail = false
    @State private var selectedTimeBlock: EADashboardReducer.State.TimeBlockState?
    @State private var todaysReminders: [CalendarService.ReminderItem] = []
    @State private var overdueReminders: [CalendarService.ReminderItem] = []
    @Environment(\.colorScheme) private var colorScheme

    // Brushed-navy used for the hero card and command bar in the Private Bank
    // palette. Kept local so we don't pollute the global Color token system.
    private static let pbNavy = Color(red: 20.0/255, green: 33.0/255, blue: 61.0/255)
    private static let pbNavyDeep = Color(red: 13.0/255, green: 22.0/255, blue: 44.0/255)
    private static let pbGoldSoft = Color.axisGold.opacity(0.18)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.xl) {
                    helloBlock
                        .axisAppear()

                    heroCard
                        .axisAppear(delay: 0.05)

                    if !store.isFocusMode {
                        prioritiesSection
                            .axisAppear(delay: 0.08)
                    }

                    dayStripSection
                        .axisAppear(delay: 0.10)

                    if !store.isFocusMode, !todaysReminders.isEmpty || !overdueReminders.isEmpty {
                        remindersSection
                    }

                    Button { showWeatherDetail = true } label: { weatherCard }
                        .buttonStyle(.plain)

                    if !store.isFocusMode, !store.activeProjects.isEmpty {
                        projectsSection
                    }

                    if !store.isFocusMode, !store.upcomingDeadlines.isEmpty {
                        deadlinesSection
                    }

                    quoteCard
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.top, AxisSpacing.sm)
                .padding(.bottom, 120)
            }
            .refreshable { store.send(.refreshTapped) }
            .background(timeOfDayBackground.ignoresSafeArea())
            .axisConfetti(trigger: store.streakDays > 0 && store.streakDays % 7 == 0)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) { commandBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $selectedTimeBlock) { block in
                TimeBlockDetailSheet(
                    block: block,
                    onOpenPlanner: {
                        selectedTimeBlock = nil
                        onNavigateToPlanner?()
                    },
                    onOpenTasks: {
                        selectedTimeBlock = nil
                        onNavigateToTasks?()
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showWeatherDetail) {
                if let weather = WeatherService.shared.currentWeather {
                    WeatherDetailView(
                        weather: weather,
                        hourly: WeatherService.shared.hourlyForecast,
                        daily: WeatherService.shared.dailyForecast
                    )
                }
            }
            .onAppear { store.send(.onAppear) }
            .task { await loadReminders() }
            .refreshable { await loadReminders() }
        }
    }

    // MARK: - Time of day

    private enum DayPeriod { case morning, midday, evening }
    private var dayPeriod: DayPeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .midday
        default: return .evening
        }
    }
    private var isEvening: Bool { dayPeriod == .evening }

    private var greetingPhrase: String {
        switch dayPeriod {
        case .morning: return "Good morning, Dr. King."
        case .midday:  return "Good afternoon, Dr. King."
        case .evening: return "Good evening, Dr. King."
        }
    }

    private var subtitleLine: String {
        switch dayPeriod {
        case .morning:
            return store.planTimeBlocks.isEmpty
                ? "Your day is in order."
                : "Your day is in order."
        case .midday:
            return store.meetingsRemaining > 0
                ? "\(store.meetingsRemaining) block\(store.meetingsRemaining == 1 ? "" : "s") remain."
                : "The afternoon is yours."
        case .evening:
            return "A strong day. Tomorrow is ready."
        }
    }

    private var datelineString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · d MMMM"
        return f.string(from: Date())
    }

    // MARK: - Background

    private var timeOfDayBackground: some View {
        let dark = colorScheme == .dark
        let colors: [Color]
        switch dayPeriod {
        case .morning:
            colors = dark
                ? [Color(red: 0.07, green: 0.07, blue: 0.10), Color(red: 0.05, green: 0.05, blue: 0.08)]
                : [Color(red: 0.984, green: 0.980, blue: 0.969), Color(red: 0.953, green: 0.941, blue: 0.910)]
        case .midday:
            colors = dark
                ? [Color(red: 0.06, green: 0.06, blue: 0.09), Color(red: 0.04, green: 0.04, blue: 0.07)]
                : [Color(red: 0.984, green: 0.980, blue: 0.969), Color(red: 0.973, green: 0.957, blue: 0.910)]
        case .evening:
            colors = [Self.pbNavyDeep, Color(red: 0.06, green: 0.08, blue: 0.14)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var foregroundOnBackground: Color {
        isEvening ? Color(red: 0.95, green: 0.93, blue: 0.86) : Color.axisInk
    }
    private var mutedOnBackground: Color {
        isEvening ? Color(red: 0.70, green: 0.67, blue: 0.60) : Color.axisInkMute
    }
    private var hairlineOnBackground: Color {
        isEvening ? Color.white.opacity(0.10) : Color.axisHairline
    }
    private var cardBackground: Color {
        isEvening ? Color.white.opacity(0.04) : Color.white
    }

    // MARK: - Hello block

    private var helloBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(datelineString.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(mutedOnBackground)
            Text(greetingPhrase)
                .font(.system(.title, design: .serif).weight(.semibold))
                .tracking(-0.4)
                .foregroundStyle(foregroundOnBackground)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(subtitleLine)
                .font(.system(size: 13))
                .foregroundStyle(mutedOnBackground)
        }
        .padding(.top, 4)
    }

    // MARK: - Hero capacity card

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            // brushed-gold corner light
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.axisGold.opacity(0.35), Color.axisGold.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: 70, y: -90)
                .blendMode(.screen)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text(heroLabel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.axisGold)

                heroValueView

                Text(heroSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.78))

                Divider()
                    .overlay(Color.white.opacity(0.12))
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 8) {
                    ForEach(heroStats, id: \.label) { stat in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stat.label.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.axisGold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(stat.value)
                                .font(.system(.callout, design: .serif).weight(.medium))
                                .foregroundStyle(Color(red: 0.95, green: 0.93, blue: 0.86))
                                .tracking(-0.3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .background(
            LinearGradient(
                colors: [Self.pbNavy, Self.pbNavyDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.axisGold.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Self.pbNavy.opacity(0.25), radius: 22, x: 0, y: 16)
    }

    private var heroLabel: String {
        switch dayPeriod {
        case .morning: return "CAPACITY INDEX"
        case .midday:  return "NEXT PROTECTED BLOCK"
        case .evening: return "THE DAY · CLOSING"
        }
    }

    @ViewBuilder
    private var heroValueView: some View {
        switch dayPeriod {
        case .morning:
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(store.energyScore)")
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .tracking(-1.5)
                    .foregroundStyle(Color(red: 0.95, green: 0.93, blue: 0.86))
                Text("/10")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        case .midday:
            Text(nextBlockTitle)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .tracking(-0.6)
                .foregroundStyle(Color(red: 0.95, green: 0.93, blue: 0.86))
                .lineLimit(2)
        case .evening:
            Text("\(store.tasksCompletedToday) shipped")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(Color(red: 0.95, green: 0.93, blue: 0.86))
        }
    }

    private var heroSubtitle: String {
        switch dayPeriod {
        case .morning:
            if let action = store.nextBestAction {
                return action.reasoning
            }
            if store.energyScore >= 7 { return "A strong morning to lead with the heaviest item." }
            if store.energyScore >= 4 { return "Moderate capacity — protect one focus window." }
            return "Lighter day ahead. Choose one thing."
        case .midday:
            if let next = store.planTimeBlocks.first {
                return "\(next.startTime) – \(next.endTime) · capacity holds"
            }
            return "The afternoon is open."
        case .evening:
            return "\(String(format: "%.1f", store.deepWorkHoursToday))h of focus · streak now \(store.streakDays) day\(store.streakDays == 1 ? "" : "s")."
        }
    }

    private struct HeroStat {
        let label: String
        let value: String
    }

    private var heroStats: [HeroStat] {
        [
            HeroStat(label: "Deadline", value: nextDeadlineValue),
            HeroStat(label: "Sleep", value: sleepValue),
            HeroStat(label: "Meetings", value: "\(store.meetingsRemaining)"),
            HeroStat(label: "Streak", value: "\(store.streakDays)d")
        ]
    }

    private var nextDeadlineValue: String {
        guard let next = store.upcomingDeadlines.first else { return "—" }
        switch next.daysLeft {
        case ..<0: return "Past"
        case 0:    return "Today"
        case 1:    return "1d"
        default:   return "\(next.daysLeft)d"
        }
    }

    private var sleepValue: String {
        guard store.isSleepLoaded, store.sleepHours > 0 else { return "—" }
        let hours = Int(store.sleepHours)
        let minutes = Int(round((store.sleepHours - Double(hours)) * 60))
        if minutes == 60 { return "\(hours + 1):00" }
        return String(format: "%d:%02d", hours, minutes)
    }

    private var nextBlockTitle: String {
        store.planTimeBlocks.first?.title ?? "The afternoon is yours"
    }

    // MARK: - Priorities (Top 3, Roman numerals)

    private struct PriorityVM: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let pill: String
        let pillTint: PillTint
        let action: PriorityAction
    }
    private enum PillTint { case gold, red, green }
    private enum PriorityAction { case openTasks, openPlanner, none }

    private var topPriorities: [PriorityVM] {
        var result: [PriorityVM] = []

        // I — next best action (AI), if any
        if let action = store.nextBestAction {
            result.append(
                PriorityVM(
                    title: action.taskTitle,
                    detail: action.reasoning,
                    pill: "RECOMMENDED",
                    pillTint: .gold,
                    action: .openTasks
                )
            )
        }

        // II — earliest overdue reminder
        if let first = overdueReminders.first {
            let days = daysOverdue(first.dueDate)
            let label = days <= 0 ? "OVERDUE" : "\(days) DAY\(days == 1 ? "" : "S") OVERDUE"
            result.append(
                PriorityVM(
                    title: first.title,
                    detail: "Past due — close it out or carry it forward.",
                    pill: label,
                    pillTint: .red,
                    action: .openTasks
                )
            )
        }

        // III — highest-priority at-risk task
        if let task = store.atRiskTasks.first {
            let pill = task.priority.uppercased()
            result.append(
                PriorityVM(
                    title: task.title,
                    detail: "Due \(formattedRelative(task.deadline)).",
                    pill: pill,
                    pillTint: pill.contains("CRITICAL") ? .red : .gold,
                    action: .openTasks
                )
            )
        }

        // Fill remaining slots with today's reminders
        for reminder in todaysReminders {
            if result.count >= 3 { break }
            if result.contains(where: { $0.title == reminder.title }) { continue }
            let detail: String
            if let due = reminder.dueDate, reminder.hasDueTime {
                let f = DateFormatter(); f.dateFormat = "h:mm a"
                detail = "Today · \(f.string(from: due))"
            } else {
                detail = "On your list for today."
            }
            result.append(
                PriorityVM(
                    title: reminder.title,
                    detail: detail,
                    pill: "TODAY",
                    pillTint: .gold,
                    action: .openTasks
                )
            )
        }

        return Array(result.prefix(3))
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: dayPeriod == .evening ? "Tomorrow's Priorities" : "Today's Priorities",
                meta: dayPeriod == .evening ? "For your approval" : "Curated"
            )

            if topPriorities.isEmpty {
                Text("Nothing demands you. Choose what's worth your morning.")
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(mutedOnBackground)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(topPriorities.enumerated()), id: \.element.id) { idx, p in
                    Button {
                        switch p.action {
                        case .openTasks: onNavigateToTasks?()
                        case .openPlanner: onNavigateToPlanner?()
                        case .none: break
                        }
                    } label: {
                        priorityRow(index: idx, model: p)
                    }
                    .buttonStyle(.plain)
                    if idx < topPriorities.count - 1 {
                        Divider().overlay(hairlineOnBackground)
                    }
                }
            }
        }
    }

    private func priorityRow(index: Int, model: PriorityVM) -> some View {
        let roman = ["I.", "II.", "III."][min(index, 2)]
        return HStack(alignment: .top, spacing: 14) {
            Text(roman)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .tracking(-0.5)
                .foregroundStyle(Color.axisGold)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(foregroundOnBackground)
                    .lineLimit(2)
                Text(model.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(mutedOnBackground)
                    .lineLimit(2)
                pillView(text: model.pill, tint: model.pillTint)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func pillView(text: String, tint: PillTint) -> some View {
        let (fg, bg): (Color, Color) = {
            switch tint {
            case .gold: return (Color.axisGold, Self.pbGoldSoft)
            case .red:  return (Color.axisDanger, Color.axisDanger.opacity(0.10))
            case .green: return (Color.axisGreenTone, Color.axisGreenSoft)
            }
        }()
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Day strip (calendar)

    private var dayStripSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: dayPeriod == .evening ? "Tomorrow's Calendar" : "The Day Ahead",
                meta: store.planTimeBlocks.isEmpty ? "Open" : "\(store.planTimeBlocks.count) block\(store.planTimeBlocks.count == 1 ? "" : "s")"
            )

            if !store.isPlanLoaded {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing your day…")
                        .font(.system(size: 12))
                        .foregroundStyle(mutedOnBackground)
                }
                .padding(.vertical, 6)
            } else if store.planTimeBlocks.isEmpty {
                Text(store.planSummary.isEmpty ? "A clear day. The hours are yours." : store.planSummary)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(mutedOnBackground)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(store.planTimeBlocks.prefix(8).enumerated()), id: \.element.id) { idx, block in
                            Button { selectedTimeBlock = block } label: {
                                eventCard(block: block, isNow: idx == 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func eventCard(block: EADashboardReducer.State.TimeBlockState, isNow: Bool) -> some View {
        let label: String = {
            switch block.blockType {
            case "meeting": return "Meeting"
            case "focusBlock": return "Focus"
            case "break": return "Break"
            case "task": return "Task"
            default: return "Block"
            }
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(block.startTime)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(isNow ? Color.axisGold : Color.axisGold)
                if isNow {
                    Text("· NOW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(isNow ? (isEvening ? Self.pbNavy : Color.axisGold) : Color.axisGold)
                }
            }
            Text(block.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(isNow ? (isEvening ? Self.pbNavy : Color.axisPaper) : foregroundOnBackground)
                .lineLimit(2)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(isNow ? (isEvening ? Self.pbNavy.opacity(0.7) : Color.white.opacity(0.7)) : mutedOnBackground)
        }
        .padding(14)
        .frame(width: 150, alignment: .leading)
        .background(
            Group {
                if isNow {
                    isEvening ? Color.axisGold : Self.pbNavy
                } else {
                    cardBackground
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isNow ? Color.clear : hairlineOnBackground,
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "Reminders",
                meta: overdueReminders.isEmpty
                    ? "\(todaysReminders.count) today"
                    : "\(overdueReminders.count) overdue"
            )

            ForEach(overdueReminders.prefix(2)) { reminder in
                reminderRow(reminder, isOverdue: true)
            }
            ForEach(todaysReminders.prefix(3)) { reminder in
                reminderRow(reminder, isOverdue: false)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(hairlineOnBackground, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reminderRow(_ item: CalendarService.ReminderItem, isOverdue: Bool) -> some View {
        Button {
            Task {
                _ = CalendarService.shared.completeReminder(id: item.id)
                await loadReminders()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .strokeBorder(
                        isOverdue ? Color.axisDanger : mutedOnBackground,
                        lineWidth: 1.5
                    )
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(.callout, design: .serif).weight(.medium))
                        .foregroundStyle(foregroundOnBackground)
                        .lineLimit(2)
                    if let due = item.dueDate {
                        Text(formattedReminderDue(due, hasTime: item.hasDueTime))
                            .font(.system(size: 10))
                            .foregroundStyle(isOverdue ? Color.axisDanger : mutedOnBackground)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weather

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: store.weatherIcon)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(Color.axisGold)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.weatherTemp)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .tracking(-1.0)
                        .foregroundStyle(foregroundOnBackground)
                    Text(weatherSubline)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(mutedOnBackground)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.locationName.isEmpty ? "LOCATION" : store.locationName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(mutedOnBackground)
                    if !store.weatherFeelsLike.isEmpty {
                        Text("Feels \(store.weatherFeelsLike)")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(foregroundOnBackground.opacity(0.9))
                    }
                }
            }
            if store.isWeatherLoaded, !store.weatherNote.isEmpty {
                Divider().overlay(hairlineOnBackground)
                Text(store.weatherNote)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(mutedOnBackground)
                    .multilineTextAlignment(.leading)
            }
            if !store.isWeatherLoaded {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading weather…")
                        .font(.system(size: 12))
                        .foregroundStyle(mutedOnBackground)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(hairlineOnBackground, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var weatherSubline: String {
        let c = store.weatherCondition.uppercased()
        let f = store.weatherFeelsLike.isEmpty ? "" : " · FEELS \(store.weatherFeelsLike)"
        return c + f
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Active Projects", meta: "\(store.activeProjects.count) in flight")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.activeProjects) { project in
                        Button { onNavigateToProjects?() } label: {
                            projectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func projectCard(project: EADashboardReducer.State.ProjectSummaryState) -> some View {
        let days = project.daysToDeadline ?? 0
        let warn = (project.daysToDeadline != nil) && days < 3
        return VStack(alignment: .leading, spacing: 12) {
            Text(project.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(foregroundOnBackground)
                .lineLimit(2)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100)
                        .fill(hairlineOnBackground)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.axisGold)
                        .frame(width: max(4, geo.size.width * CGFloat(project.progress)), height: 4)
                }
            }
            .frame(height: 4)
            HStack {
                Text("\(Int(project.progress * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(mutedOnBackground)
                Spacer()
                if let d = project.daysToDeadline {
                    Text("\(d)D LEFT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(warn ? Color.axisDanger : mutedOnBackground)
                }
            }
        }
        .padding(14)
        .frame(width: 180, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hairlineOnBackground, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Deadlines

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Upcoming Deadlines", meta: "\(store.upcomingDeadlines.count) ahead")
            VStack(spacing: 0) {
                ForEach(Array(store.upcomingDeadlines.enumerated()), id: \.element.id) { idx, deadline in
                    deadlineRow(deadline)
                    if idx < store.upcomingDeadlines.count - 1 {
                        Divider().overlay(hairlineOnBackground)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hairlineOnBackground, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func deadlineRow(_ deadline: EADashboardReducer.State.DeadlineState) -> some View {
        let tint: Color = {
            if deadline.daysLeft <= 1 { return .axisDanger }
            if deadline.daysLeft <= 3 { return .axisGold }
            return foregroundOnBackground
        }()
        let label: String = {
            if deadline.daysLeft == 0 { return "TODAY" }
            if deadline.daysLeft == 1 { return "1D" }
            return "\(deadline.daysLeft)D"
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.title)
                    .font(.system(.callout, design: .serif).weight(.medium))
                    .foregroundStyle(foregroundOnBackground)
                Text(deadline.category.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(mutedOnBackground)
            }
            Spacer()
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Quote (kept — Bible + Grandma's Version)

    private var quoteCard: some View {
        Group {
            if !store.dailyQuote.isEmpty {
                VStack(spacing: 16) {
                    Text("✦")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.axisGold)

                    VStack(spacing: 10) {
                        Text("\u{201C}\(store.dailyQuote)\u{201D}")
                            .font(.system(.subheadline, design: .serif).italic())
                            .foregroundStyle(foregroundOnBackground)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(store.dailyQuoteAuthor.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.0)
                            .foregroundStyle(Color.axisGold)
                    }

                    if !store.dailyQuoteGrandma.isEmpty {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("🪑")
                                    .font(.system(size: 11))
                                Text("Grandma's Version")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.axisGold)
                                    .textCase(.uppercase)
                            }
                            Text("\u{201C}\(store.dailyQuoteGrandma)\u{201D}")
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(foregroundOnBackground.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Self.pbGoldSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 8) {
                        quoteButton(systemImage: "chevron.left", label: nil) {
                            store.send(.previousQuote)
                        }
                        .disabled(store.quoteHistoryIndex <= 0)
                        .opacity(store.quoteHistoryIndex <= 0 ? 0.4 : 1)

                        quoteButton(
                            systemImage: store.quoteHistoryIndex < store.quoteHistory.count - 1 ? "chevron.right" : "arrow.clockwise",
                            label: store.quoteHistoryIndex < store.quoteHistory.count - 1 ? "Next" : "New Word"
                        ) {
                            store.send(.refreshQuote)
                        }

                        quoteButton(systemImage: "square.and.arrow.up", label: "Share") {
                            let shareText = "\"\(store.dailyQuote)\"\n— \(store.dailyQuoteAuthor)\n\n\(store.dailyQuoteGrandma)\n\n— Shared from AXIS"
                            PlatformServices.share(items: [shareText])
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(hairlineOnBackground, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func quoteButton(systemImage: String, label: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                }
            }
            .foregroundStyle(Color.axisGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Self.pbGoldSoft)
            .clipShape(Capsule())
        }
    }

    // MARK: - Section header

    private func sectionHeader(title: String, meta: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(foregroundOnBackground)
            Spacer()
            Text(meta.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.axisGold)
        }
    }

    // MARK: - Command bar

    private var commandBar: some View {
        HStack(spacing: 10) {
            Text("EA")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.axisGold)
            TextField(
                "A request, Dr. King?",
                text: $store.quickAddText.sending(\.quickAddTextChanged)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.axisPaper)
            .tint(Color.axisGold)
            .onSubmit { store.send(.quickAddSubmit) }
            if !store.quickAddText.isEmpty {
                Button { store.send(.quickAddSubmit) } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Self.pbNavy)
                        .frame(width: 28, height: 28)
                        .background(Color.axisGold)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Self.pbNavy)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.axisGold.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: Self.pbNavy.opacity(0.35), radius: 18, x: 0, y: 10)
        .padding(.horizontal, AxisSpacing.lg)
        .padding(.bottom, 12)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { onSettingsTapped?() } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(mutedOnBackground)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: AxisSpacing.md) {
                Button { onToggleDarkMode?() } label: {
                    Image(systemName: isDarkMode ? "sun.max" : "moon")
                        .foregroundStyle(mutedOnBackground)
                }
                Button { store.send(.toggleFocusMode) } label: {
                    Image(systemName: store.isFocusMode ? "eye.slash" : "eye")
                        .foregroundStyle(store.isFocusMode ? Color.axisWarning : mutedOnBackground)
                }
                Button { onAddTapped?() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.axisGold)
                        .font(.title3)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedReminderDue(_ date: Date, hasTime: Bool) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if hasTime { f.dateStyle = .none; f.timeStyle = .short } else { f.dateStyle = .medium; f.timeStyle = .none }
        if cal.isDateInToday(date) { return hasTime ? "Today · \(f.string(from: date))" : "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let df = DateFormatter(); df.dateStyle = .medium
        if hasTime { df.timeStyle = .short }
        return df.string(from: date)
    }

    private func formattedRelative(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") ago" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return "in \(days) days"
    }

    private func daysOverdue(_ date: Date?) -> Int {
        guard let date else { return 0 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(0, days)
    }

    private func loadReminders() async {
        let granted = await CalendarService.shared.requestRemindersAccess()
        guard granted else { return }
        let all = await CalendarService.shared.fetchAllReminders()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        var today: [CalendarService.ReminderItem] = []
        var overdue: [CalendarService.ReminderItem] = []
        for item in all where !item.isCompleted {
            guard let due = item.dueDate else { continue }
            if due < startOfDay {
                overdue.append(item)
            } else if due < startOfTomorrow {
                today.append(item)
            }
        }
        overdue.sort { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        today.sort { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        await MainActor.run {
            self.overdueReminders = overdue
            self.todaysReminders = today
        }
    }
}

#Preview {
    EADashboardView(
        store: Store(initialState: EADashboardReducer.State()) {
            EADashboardReducer()
        }
    )
}

// MARK: - Time Block Detail Sheet

struct TimeBlockDetailSheet: View {
    let block: EADashboardReducer.State.TimeBlockState
    let onOpenPlanner: () -> Void
    let onOpenTasks: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var blockLabel: String {
        switch block.blockType {
        case "meeting": return "Meeting"
        case "focusBlock": return "Focus Block"
        case "break": return "Break"
        case "task": return "Task"
        default: return "Block"
        }
    }

    private var blockIcon: String {
        switch block.blockType {
        case "meeting": return "person.2.fill"
        case "focusBlock": return "target"
        case "break": return "cup.and.saucer.fill"
        case "task": return "checkmark.circle.fill"
        default: return "clock"
        }
    }

    private var blockTint: Color {
        switch block.blockType {
        case "meeting": return .purple
        case "focusBlock": return .blue
        case "break": return .green
        case "task": return Color.axisAccent
        default: return .gray
        }
    }

    private var durationText: String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        guard let start = df.date(from: block.startTime),
              let end = df.date(from: block.endTime) else { return "" }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes <= 0 { return "" }
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.xl) {
                    VStack(alignment: .leading, spacing: AxisSpacing.sm) {
                        HStack(spacing: AxisSpacing.sm) {
                            Image(systemName: blockIcon)
                                .foregroundStyle(blockTint)
                            Text(blockLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(blockTint)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        Text(block.title)
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: AxisSpacing.md) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text("\(block.startTime) – \(block.endTime)")
                                .font(.body.weight(.medium))
                            Spacer()
                            if !durationText.isEmpty {
                                Text(durationText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(AxisSpacing.lg)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))

                    VStack(spacing: AxisSpacing.md) {
                        Button {
                            onOpenPlanner()
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("Open in Planner")
                            }
                        }
                        .buttonStyle(.axisPrimary)

                        if block.blockType == "task" {
                            Button {
                                onOpenTasks()
                            } label: {
                                HStack {
                                    Image(systemName: "checklist")
                                    Text("View Tasks")
                                }
                            }
                            .buttonStyle(.axisSecondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.top, AxisSpacing.lg)
            }
            .navigationTitle("Timeline Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
