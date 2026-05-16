import ComposableArchitecture
import EventKit
import SwiftUI

extension Notification.Name {
    static let axisFocusWorkflowQuickAdd = Notification.Name("axisFocusWorkflowQuickAdd")
}

// The Workflow tab is now a single Reminders-first view. Tasks / Timeline /
// Projects have been collapsed into this one screen — everything you need to
// do lives as an iOS Reminder that can optionally be placed on the calendar.
// The tasksStore / plannerStore / projectsStore parameters are kept so the
// AppReducer wiring stays stable while the legacy reducers are retired.
struct WorkflowView: View {
    let tasksStore: StoreOf<EATaskReducer>
    let plannerStore: StoreOf<EAPlannerReducer>
    let projectsStore: StoreOf<EAProjectReducer>

    enum Grouping: String, CaseIterable, Identifiable {
        case date, list
        var id: String { rawValue }
        var label: String {
            switch self {
            case .date: return "By Date"
            case .list: return "By List"
            }
        }
        var icon: String {
            switch self {
            case .date: return "calendar"
            case .list: return "list.bullet.rectangle"
            }
        }
    }

    /// How the Today section breaks itself down once it grows past a few items.
    enum TodaySubGroup: String, CaseIterable, Identifiable {
        case time, project
        var id: String { rawValue }
        var label: String {
            switch self {
            case .time: return "Time of Day"
            case .project: return "Project / List"
            }
        }
        var icon: String {
            switch self {
            case .time: return "clock"
            case .project: return "list.bullet.rectangle"
            }
        }
    }

    enum ReminderFilter: Equatable {
        case none
        case label(String)
        case priority(Int)
        case list(String)
        // Smart-list presets — compound filters that override sectioning.
        case overdueOnly
        case noDateOnly
        case todayHighPriority
        case highPriorityOnly
        case pinnedOnly

        var icon: String {
            switch self {
            case .none: return "line.3.horizontal.decrease"
            case .label: return "number"
            case .priority: return "flag.fill"
            case .list: return "list.bullet.rectangle"
            case .overdueOnly: return "exclamationmark.triangle"
            case .noDateOnly: return "calendar.badge.minus"
            case .todayHighPriority: return "sparkles"
            case .highPriorityOnly: return "flag.fill"
            case .pinnedOnly: return "pin.fill"
            }
        }
    }

    @State private var vm = RemindersViewModel()
    @State private var showAddSheet = false
    @State private var selectedReminder: CalendarService.ReminderItem?
    @State private var inlineDateReminder: CalendarService.ReminderItem?
    @State private var expandedReminders: Set<String> = []
    @State private var newQuickTitle = ""
    @FocusState private var quickFocused: Bool
    @AppStorage("workflow.grouping") private var grouping: Grouping = .date
    @AppStorage("workflow.todaySubGroup") private var todaySubGroup: TodaySubGroup = .time
    @State private var filter: ReminderFilter = .none

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    deniedState
                case .loaded:
                    loadedList
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reminders")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(Color.axisAccent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Group", selection: $grouping) {
                            ForEach(Grouping.allCases) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        if grouping == .date {
                            Picker("Today Sub-group", selection: $todaySubGroup) {
                                ForEach(TodaySubGroup.allCases) { option in
                                    Label(option.label, systemImage: option.icon).tag(option)
                                }
                            }
                        }
                        Divider()
                        smartListPresets
                        Divider()
                        filterSubmenus
                    } label: {
                        Image(systemName: filter == .none && grouping == .date
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(filter == .none ? .secondary : Color.axisAccent)
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisAccent)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ReminderEditorSheet(mode: .create) { result in
                    if case let .saved(id) = result {
                        Task { await vm.reload(); selectedReminder = vm.byId[id] }
                    }
                }
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderEditorSheet(mode: .edit(reminder)) { result in
                    Task { await vm.reload() }
                    if case .deleted = result { selectedReminder = nil }
                }
            }
            .sheet(item: $inlineDateReminder) { reminder in
                InlineDatePickerSheet(reminder: reminder) {
                    Task { await vm.reload() }
                    inlineDateReminder = nil
                }
                .presentationDetents([.medium])
            }
            .task { await vm.requestAccessAndLoad() }
            .refreshable { await vm.reload() }
            .onReceive(NotificationCenter.default.publisher(for: .axisFocusWorkflowQuickAdd)) { _ in
                quickFocused = true
                Task { await vm.reload() }
            }
        }
    }

    // MARK: - Loaded list

    private var loadedList: some View {
        List {
            // Quick add row always at the top — supports natural-language
            // input like "Call mom tomorrow 5pm p1 every weekday".
            Section {
                HStack(spacing: AxisSpacing.sm) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.axisAccent)
                    TextField("Add: e.g. \"Call mom tomorrow 5pm p1\"", text: $newQuickTitle)
                        .focused($quickFocused)
                        .submitLabel(.done)
                        .onSubmit { submitQuickAdd() }
                    if !newQuickTitle.isEmpty {
                        Button("Add") { submitQuickAdd() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.axisAccent)
                    }
                }
                if !newQuickTitle.isEmpty {
                    quickAddPreview
                }
                if filter != .none {
                    HStack(spacing: AxisSpacing.sm) {
                        Label(filterLabel(filter), systemImage: filter.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.axisAccent.opacity(0.15)))
                            .foregroundStyle(Color.axisAccent)
                        Spacer(minLength: 0)
                        Button("Clear") {
                            filter = .none
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            // Smart-list presets override the date/list grouping with a single
            // flat list of just-the-matching items.
            if let presetItems = smartListItems() {
                section(title: filterLabel(filter), items: presetItems, accent: Color.axisAccent)
            } else {
                switch grouping {
                case .date:
                    overdueSection(items: filtered(vm.overdue))
                    todaySections()
                    section(title: "Upcoming", items: filtered(vm.upcoming), accent: Color.axisInfo)
                    section(title: "No Date", items: filtered(vm.undated), accent: Color.secondary)
                case .list:
                    ForEach(itemsGroupedByList(), id: \.title) { group in
                        section(title: group.title, items: filtered(group.items), accent: Color.axisAccent)
                    }
                }
            }

            if vm.isAllEmpty {
                AxisEmptyState(
                    icon: "checkmark.seal",
                    title: "You're clear",
                    message: "No open reminders. Tap + to add one, or ask AXIS in chat.",
                    actionTitle: "Add Reminder",
                    action: { showAddSheet = true }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func section(title: String, items: [CalendarService.ReminderItem], accent: Color) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button { selectedReminder = item } label: {
                        ReminderRow(
                            item: item,
                            accent: accent,
                            subtaskProgress: vm.subtaskProgress[item.id],
                            subtasks: vm.subtasksByReminder[item.id] ?? [],
                            isExpanded: expandedReminders.contains(item.id),
                            isPinned: vm.isPinnedToday(item.id),
                            onToggle: { await vm.toggleComplete(item) },
                            onTapDate: { inlineDateReminder = item },
                            onToggleExpanded: { toggleExpansion(item.id) },
                            onToggleSubtask: { vm.toggleSubtask($0) }
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await vm.toggleComplete(item) }
                        } label: {
                            Label(item.isCompleted ? "Uncomplete" : "Complete", systemImage: "checkmark.circle.fill")
                        }
                        .tint(Color.axisAccent)
                        Button {
                            vm.togglePinToday(item.id)
                        } label: {
                            let pinned = vm.isPinnedToday(item.id)
                            Label(pinned ? "Unpin" : "Pin to Today",
                                  systemImage: pinned ? "pin.slash.fill" : "pin.fill")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        rescheduleMenu(for: item)
                    }
                }
                .onMove { from, to in
                    vm.moveItems(in: items, from: from, to: to)
                }
            } header: {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Denied / Access prompt

    private var deniedState: some View {
        VStack(spacing: AxisSpacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Axis needs access to Reminders")
                .font(.headline)
            Text("Enable Reminders access in Settings to use the Workflow tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    PlatformServices.openURL(url)
                }
                #endif
            }
            .buttonStyle(.axisPrimary(fullWidth: false))
        }
        .padding(AxisSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    // MARK: - Filter & smart lists

    private func filterLabel(_ filter: ReminderFilter) -> String {
        switch filter {
        case .none: return "All Reminders"
        case .label(let l): return "#\(l)"
        case .priority(let p):
            switch p {
            case 1...3: return "High Priority"
            case 4...6: return "Medium Priority"
            default: return "Low Priority"
            }
        case .list(let id):
            return vm.allLists.first(where: { $0.id == id })?.title ?? "List"
        case .overdueOnly: return "Overdue"
        case .noDateOnly: return "No Date"
        case .todayHighPriority: return "Today + High"
        case .highPriorityOnly: return "High Priority Anywhere"
        case .pinnedOnly: return "Pinned to Today"
        }
    }

    @ViewBuilder
    private var smartListPresets: some View {
        Section("Smart Lists") {
            Button {
                filter = .none
            } label: {
                Label("All", systemImage: "tray.full")
            }
            Button {
                filter = .todayHighPriority
            } label: {
                Label("Today + High", systemImage: "sparkles")
            }
            Button {
                filter = .overdueOnly
            } label: {
                Label("Overdue", systemImage: "exclamationmark.triangle")
            }
            Button {
                filter = .noDateOnly
            } label: {
                Label("No Date", systemImage: "calendar.badge.minus")
            }
            Button {
                filter = .highPriorityOnly
            } label: {
                Label("High Priority", systemImage: "flag.fill")
            }
            Button {
                filter = .pinnedOnly
            } label: {
                Label("Pinned", systemImage: "pin.fill")
            }
        }
    }

    @ViewBuilder
    private var filterSubmenus: some View {
        let labels = discoveredLabels()
        if !labels.isEmpty {
            Menu("Filter by Label") {
                ForEach(labels, id: \.self) { tag in
                    Button {
                        filter = .label(tag)
                    } label: {
                        Label("#\(tag)", systemImage: "number")
                    }
                }
            }
        }
        Menu("Filter by Priority") {
            Button { filter = .priority(1) } label: { Label("High", systemImage: "flag.fill") }
            Button { filter = .priority(5) } label: { Label("Medium", systemImage: "flag") }
            Button { filter = .priority(9) } label: { Label("Low", systemImage: "flag.slash") }
        }
        if vm.allLists.count > 1 {
            Menu("Filter by List") {
                ForEach(vm.allLists) { list in
                    Button {
                        filter = .list(list.id)
                    } label: {
                        Label(list.title, systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
    }

    private func discoveredLabels() -> [String] {
        let all = vm.overdue + vm.today + vm.upcoming + vm.undated
        return Array(Set(all.flatMap(\.labels))).sorted()
    }

    /// Returns true if the item passes the active filter.
    private func passesFilter(_ item: CalendarService.ReminderItem) -> Bool {
        switch filter {
        case .none, .overdueOnly, .noDateOnly, .todayHighPriority, .highPriorityOnly, .pinnedOnly:
            return true // these are applied at the bucket-selection stage
        case .label(let l):
            return item.labels.contains(l)
        case .priority(let p):
            switch p {
            case 1...3: return item.priority >= 1 && item.priority <= 3
            case 4...6: return item.priority >= 4 && item.priority <= 6
            default: return item.priority >= 7 && item.priority <= 9
            }
        case .list(let id):
            return item.calendarIdentifier == id
        }
    }

    private func filtered(_ items: [CalendarService.ReminderItem]) -> [CalendarService.ReminderItem] {
        guard filter != .none else { return items }
        return items.filter(passesFilter)
    }

    /// Overdue section variant with a trailing "Move to Today" button that
    /// batch-reschedules every overdue item.
    @ViewBuilder
    private func overdueSection(items: [CalendarService.ReminderItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button { selectedReminder = item } label: {
                        ReminderRow(
                            item: item,
                            accent: Color.axisDanger,
                            subtaskProgress: vm.subtaskProgress[item.id],
                            isPinned: vm.isPinnedToday(item.id),
                            onToggle: { await vm.toggleComplete(item) },
                            onTapDate: { inlineDateReminder = item }
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(item) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await vm.toggleComplete(item) }
                        } label: { Label("Complete", systemImage: "checkmark.circle.fill") }
                        .tint(Color.axisAccent)
                        Button {
                            vm.togglePinToday(item.id)
                        } label: {
                            let pinned = vm.isPinnedToday(item.id)
                            Label(pinned ? "Unpin" : "Pin to Today",
                                  systemImage: pinned ? "pin.slash.fill" : "pin.fill")
                        }
                        .tint(.orange)
                    }
                    .contextMenu { rescheduleMenu(for: item) }
                }
                .onMove { from, to in vm.moveItems(in: items, from: from, to: to) }
            } header: {
                HStack {
                    Text("Overdue")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.axisDanger)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Button {
                        postponeAllOverdue(items)
                    } label: {
                        Label("Move to Today", systemImage: "arrow.uturn.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.axisAccent)
                    }
                    .buttonStyle(.plain)
                    .textCase(nil)
                }
            }
        }
    }

    private func toggleExpansion(_ id: String) {
        if expandedReminders.contains(id) {
            expandedReminders.remove(id)
        } else {
            expandedReminders.insert(id)
        }
    }

    private func postponeAllOverdue(_ items: [CalendarService.ReminderItem]) {
        let today = Calendar.current.startOfDay(for: Date())
        Task {
            for item in items {
                var target = today
                if item.hasDueTime, let original = item.dueDate {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: original)
                    if let combined = Calendar.current.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: today) {
                        target = combined
                    }
                }
                _ = CalendarService.shared.updateReminder(
                    id: item.id,
                    dueDate: target,
                    includeDueTime: item.hasDueTime
                )
            }
            await vm.reload()
        }
    }

    /// Renders Today as one section (when small) or split into buckets when
    /// it has 3+ items. The split axis depends on todaySubGroup: time-of-day
    /// (Morning / Afternoon / Evening / No Time) or by Reminders list/project.
    @ViewBuilder
    private func todaySections() -> some View {
        let items = filtered(vm.today)
        if items.count < 3 {
            section(title: "Today", items: items, accent: Color.axisAccent)
        } else {
            switch todaySubGroup {
            case .time:
                let buckets = bucketByTimeOfDay(items)
                section(title: "Today · Morning", items: buckets.morning, accent: Color.axisAccent)
                section(title: "Today · Afternoon", items: buckets.afternoon, accent: Color.axisAccent)
                section(title: "Today · Evening", items: buckets.evening, accent: Color.axisAccent)
                section(title: "Today · No Time", items: buckets.untimed, accent: Color.secondary)
            case .project:
                let groups = bucketByProject(items)
                ForEach(groups, id: \.title) { group in
                    section(title: "Today · \(group.title)", items: group.items, accent: Color.axisAccent)
                }
            }
        }
    }

    private func bucketByProject(_ items: [CalendarService.ReminderItem]) -> [ListGroup] {
        let grouped = Dictionary(grouping: items) { $0.calendarTitle ?? "Reminders" }
        return grouped
            .map { ListGroup(title: $0.key, items: $0.value) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private struct TimeOfDayBuckets {
        var morning: [CalendarService.ReminderItem] = []
        var afternoon: [CalendarService.ReminderItem] = []
        var evening: [CalendarService.ReminderItem] = []
        var untimed: [CalendarService.ReminderItem] = []
    }

    private func bucketByTimeOfDay(_ items: [CalendarService.ReminderItem]) -> TimeOfDayBuckets {
        var buckets = TimeOfDayBuckets()
        let cal = Calendar.current
        for item in items {
            guard item.hasDueTime, let due = item.dueDate else {
                buckets.untimed.append(item); continue
            }
            let hour = cal.component(.hour, from: due)
            switch hour {
            case 0..<12: buckets.morning.append(item)
            case 12..<17: buckets.afternoon.append(item)
            default: buckets.evening.append(item)
            }
        }
        return buckets
    }

    /// For smart-list presets, returns the flat result list. Returns nil for
    /// non-preset filters (which use the normal section pipeline + passesFilter).
    private func smartListItems() -> [CalendarService.ReminderItem]? {
        switch filter {
        case .overdueOnly:
            return vm.overdue
        case .noDateOnly:
            return vm.undated
        case .todayHighPriority:
            return vm.today.filter { $0.priority >= 1 && $0.priority <= 3 }
        case .highPriorityOnly:
            let all = vm.overdue + vm.today + vm.upcoming + vm.undated
            return all.filter { $0.priority >= 1 && $0.priority <= 3 }
        case .pinnedOnly:
            let all = vm.overdue + vm.today + vm.upcoming + vm.undated
            return all.filter { vm.isPinnedToday($0.id) }
        default:
            return nil
        }
    }

    // MARK: - Reschedule

    @ViewBuilder
    private func rescheduleMenu(for item: CalendarService.ReminderItem) -> some View {
        Menu {
            Button { reschedule(item, to: RescheduleTarget.today.resolve(from: Date())) } label: {
                Label("Today", systemImage: "sun.max")
            }
            Button { reschedule(item, to: RescheduleTarget.tomorrow.resolve(from: Date())) } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }
            Button { reschedule(item, to: RescheduleTarget.thisWeekend.resolve(from: Date())) } label: {
                Label("This Weekend", systemImage: "beach.umbrella")
            }
            Button { reschedule(item, to: RescheduleTarget.nextWeek.resolve(from: Date())) } label: {
                Label("Next Week", systemImage: "calendar.badge.clock")
            }
            Divider()
            Button { selectedReminder = item } label: {
                Label("Pick a Date…", systemImage: "calendar")
            }
            if item.dueDate != nil {
                Button(role: .destructive) {
                    Task { await clearDueDate(item) }
                } label: {
                    Label("Clear Due Date", systemImage: "calendar.badge.minus")
                }
            }
        } label: {
            Label("Reschedule", systemImage: "arrow.triangle.2.circlepath")
        }
        Button {
            Task { await vm.toggleComplete(item) }
        } label: {
            Label(item.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: "checkmark.circle")
        }
        Button(role: .destructive) {
            Task { await vm.delete(item) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private enum RescheduleTarget {
        case today, tomorrow, thisWeekend, nextWeek

        func resolve(from now: Date) -> Date {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: now)
            switch self {
            case .today:
                return startOfDay
            case .tomorrow:
                return cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            case .thisWeekend:
                // Next Saturday from today (or today if it's already Saturday).
                let weekday = cal.component(.weekday, from: startOfDay) // Sun=1, Sat=7
                let daysUntilSaturday = (7 - weekday + 7) % 7
                let offset = daysUntilSaturday == 0 ? 0 : daysUntilSaturday
                return cal.date(byAdding: .day, value: offset, to: startOfDay) ?? startOfDay
            case .nextWeek:
                // Next Monday from today.
                let weekday = cal.component(.weekday, from: startOfDay) // Sun=1, Mon=2
                let daysUntilMonday = (2 - weekday + 7) % 7
                let offset = daysUntilMonday == 0 ? 7 : daysUntilMonday
                return cal.date(byAdding: .day, value: offset, to: startOfDay) ?? startOfDay
            }
        }
    }

    private func reschedule(_ item: CalendarService.ReminderItem, to newDate: Date) {
        // Preserve time-of-day if the original reminder had one.
        var target = newDate
        if item.hasDueTime, let original = item.dueDate {
            let cal = Calendar.current
            let timeParts = cal.dateComponents([.hour, .minute], from: original)
            if let combined = cal.date(bySettingHour: timeParts.hour ?? 0, minute: timeParts.minute ?? 0, second: 0, of: newDate) {
                target = combined
            }
        }
        Task {
            _ = CalendarService.shared.updateReminder(
                id: item.id,
                dueDate: target,
                includeDueTime: item.hasDueTime
            )
            await vm.reload()
        }
    }

    private func clearDueDate(_ item: CalendarService.ReminderItem) async {
        _ = CalendarService.shared.updateReminder(
            id: item.id,
            clearDueDate: true
        )
        await vm.reload()
    }

    private struct ListGroup {
        let title: String
        let items: [CalendarService.ReminderItem]
    }

    private func itemsGroupedByList() -> [ListGroup] {
        let all = vm.overdue + vm.today + vm.upcoming + vm.undated
        let grouped = Dictionary(grouping: all) { $0.calendarTitle ?? "Reminders" }
        return grouped
            .map { key, value in
                ListGroup(
                    title: key,
                    items: value.sorted {
                        ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
                    }
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder
    private var quickAddPreview: some View {
        let parsed = QuickAddParser.parse(newQuickTitle)
        let chips = previewChips(for: parsed)
        if !chips.isEmpty {
            HStack(spacing: AxisSpacing.xs) {
                ForEach(chips, id: \.0) { chip in
                    Label(chip.1, systemImage: chip.0)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.axisAccent.opacity(0.12)))
                        .foregroundStyle(Color.axisAccent)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func previewChips(for parsed: QuickAddParser.Result) -> [(String, String)] {
        var chips: [(String, String)] = []
        if let due = parsed.dueDate {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = parsed.includesTime ? .short : .none
            chips.append(("calendar", f.string(from: due)))
        }
        if parsed.priority > 0 {
            let label: String
            switch parsed.priority {
            case 1...3: label = "High"
            case 4...6: label = "Medium"
            default: label = "Low"
            }
            chips.append(("flag.fill", label))
        }
        if parsed.recurrence != .none {
            chips.append(("arrow.triangle.2.circlepath", parsed.recurrence.label))
        }
        return chips
    }

    private func submitQuickAdd() {
        let trimmed = newQuickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsed = QuickAddParser.parse(trimmed)
        let finalTitle = parsed.title.isEmpty ? trimmed : parsed.title
        Task {
            _ = CalendarService.shared.createReminder(
                title: finalTitle,
                dueDate: parsed.dueDate,
                includeDueTime: parsed.includesTime,
                priority: parsed.priority,
                recurrence: parsed.recurrence
            )
            await MainActor.run {
                newQuickTitle = ""
                quickFocused = false
            }
            await vm.reload()
        }
    }
}

// MARK: - Reminder Row

private struct ReminderRow: View {
    let item: CalendarService.ReminderItem
    let accent: Color
    let subtaskProgress: RemindersViewModel.SubtaskProgress?
    var subtasks: [Subtask] = []
    var isExpanded: Bool = false
    var isPinned: Bool = false
    let onToggle: () async -> Void
    var onTapDate: (() -> Void)? = nil
    var onToggleExpanded: (() -> Void)? = nil
    var onToggleSubtask: ((Subtask) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: AxisSpacing.md) {
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? accent : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted)
                        .lineLimit(2)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: AxisSpacing.sm) {
                    if let due = item.dueDate {
                        Button {
                            onTapDate?()
                        } label: {
                            Label {
                                Text(formattedDue(due, includesTime: item.hasDueTime))
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if let summary = item.recurrenceSummary {
                        Label {
                            Text(summary)
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if let progress = subtaskProgress, progress.total > 0 {
                        Button {
                            onToggleExpanded?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: progress.done == progress.total ? "checklist.checked" : "checklist")
                                Text("\(progress.done)/\(progress.total)")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.caption)
                            .foregroundStyle(progress.done == progress.total ? accent : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if let calName = item.calendarTitle {
                        Text(calName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if item.priority > 0 {
                        Text(priorityLabel(item.priority))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(accent.opacity(0.15)))
                            .foregroundStyle(accent)
                    }
                    ForEach(item.labels.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.axisAccent.opacity(0.12)))
                            .foregroundStyle(Color.axisAccent)
                    }
                    if item.labels.count > 3 {
                        Text("+\(item.labels.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if isExpanded && !subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(subtasks) { sub in
                            Button {
                                onToggleSubtask?(sub)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(sub.isCompleted ? accent : .secondary)
                                    Text(sub.title)
                                        .font(.subheadline)
                                        .strikethrough(sub.isCompleted)
                                        .foregroundStyle(sub.isCompleted ? .secondary : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func formattedDue(_ date: Date, includesTime: Bool) -> String {
        let f = DateFormatter()
        if includesTime {
            f.dateStyle = .medium; f.timeStyle = .short
        } else {
            f.dateStyle = .medium; f.timeStyle = .none
        }
        return f.string(from: date)
    }

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1...3: return "High"
        case 4...6: return "Medium"
        case 7...9: return "Low"
        default: return ""
        }
    }
}

// MARK: - View Model

@Observable
final class RemindersViewModel {
    enum LoadState { case loading, denied, loaded }
    struct SubtaskProgress: Equatable {
        let done: Int
        let total: Int
    }
    private static let sortOrderKey = "workflow.sortOrder.v1"
    private static let pinnedTodayKey = "workflow.pinnedToday.v1"
    var state: LoadState = .loading
    var overdue: [CalendarService.ReminderItem] = []
    var today: [CalendarService.ReminderItem] = []
    var upcoming: [CalendarService.ReminderItem] = []
    var undated: [CalendarService.ReminderItem] = []
    var byId: [String: CalendarService.ReminderItem] = [:]
    var subtaskProgress: [String: SubtaskProgress] = [:]
    var subtasksByReminder: [String: [Subtask]] = [:]
    var allLists: [CalendarService.ReminderList] = []
    /// Manual sort overrides keyed by reminder calendarItemIdentifier. EventKit
    /// has no per-reminder ordering API, so we store our own.
    private var sortOrder: [String: Int] = [:]
    /// Reminders the user explicitly pinned to Today. These appear in the
    /// Today section regardless of their actual due date (Todoist-style
    /// "starred for today" beyond just priority).
    private(set) var pinnedToday: Set<String> = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.sortOrderKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            sortOrder = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.pinnedTodayKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            pinnedToday = decoded
        }
    }

    private func persistSortOrder() {
        if let data = try? JSONEncoder().encode(sortOrder) {
            UserDefaults.standard.set(data, forKey: Self.sortOrderKey)
        }
    }

    private func persistPinnedToday() {
        if let data = try? JSONEncoder().encode(pinnedToday) {
            UserDefaults.standard.set(data, forKey: Self.pinnedTodayKey)
        }
    }

    func isPinnedToday(_ id: String) -> Bool { pinnedToday.contains(id) }

    func togglePinToday(_ id: String) {
        if pinnedToday.contains(id) {
            pinnedToday.remove(id)
        } else {
            pinnedToday.insert(id)
        }
        persistPinnedToday()
        Task { await reload() }
    }

    /// Comparator: lower sortOrder wins; absence treated as Int.max so unsorted
    /// items keep their default date-ordering relative to each other.
    func compare(_ lhs: CalendarService.ReminderItem, _ rhs: CalendarService.ReminderItem) -> Bool {
        let l = sortOrder[lhs.id] ?? Int.max
        let r = sortOrder[rhs.id] ?? Int.max
        if l != r { return l < r }
        // Fall back to due date.
        return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    }

    func moveItems(in items: [CalendarService.ReminderItem], from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            sortOrder[item.id] = index
        }
        persistSortOrder()
        Task { await reload() }
    }

    var isAllEmpty: Bool {
        overdue.isEmpty && today.isEmpty && upcoming.isEmpty && undated.isEmpty
    }

    func requestAccessAndLoad() async {
        let granted = await CalendarService.shared.requestRemindersAccess()
        _ = await CalendarService.shared.requestAccess()
        state = granted ? .loaded : .denied
        if granted { await reload() }
    }

    func reload() async {
        let items = await CalendarService.shared.fetchAllReminders()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        var overdueBucket: [CalendarService.ReminderItem] = []
        var todayBucket: [CalendarService.ReminderItem] = []
        var upcomingBucket: [CalendarService.ReminderItem] = []
        var undatedBucket: [CalendarService.ReminderItem] = []
        var map: [String: CalendarService.ReminderItem] = [:]

        for item in items where !item.isCompleted {
            map[item.id] = item
            // Pinned reminders surface in Today regardless of date so the
            // user can curate a daily focus list beyond just priority=High.
            if pinnedToday.contains(item.id) {
                todayBucket.append(item)
                continue
            }
            if let due = item.dueDate {
                if due < startOfDay {
                    overdueBucket.append(item)
                } else if due < startOfTomorrow {
                    todayBucket.append(item)
                } else {
                    upcomingBucket.append(item)
                }
            } else {
                undatedBucket.append(item)
            }
        }
        overdueBucket.sort(by: compare)
        todayBucket.sort(by: compare)
        upcomingBucket.sort(by: compare)
        undatedBucket.sort(by: compare)

        overdue = overdueBucket
        today = todayBucket
        upcoming = upcomingBucket
        undated = undatedBucket
        byId = map

        let grouped = PersistenceService.shared.fetchAllReminderSubtasks()
        subtaskProgress = grouped.mapValues { rows in
            SubtaskProgress(done: rows.filter(\.isCompleted).count, total: rows.count)
        }
        subtasksByReminder = grouped
        allLists = CalendarService.shared.availableReminderLists()
    }

    func toggleSubtask(_ subtask: Subtask) {
        subtask.isCompleted.toggle()
        PersistenceService.shared.updateSubtasks()
        Task { await reload() }
    }

    func toggleComplete(_ item: CalendarService.ReminderItem) async {
        _ = item.isCompleted
            ? CalendarService.shared.uncompleteReminder(id: item.id)
            : CalendarService.shared.completeReminder(id: item.id)
        await reload()
    }

    func delete(_ item: CalendarService.ReminderItem) async {
        _ = CalendarService.shared.deleteReminder(id: item.id)
        PersistenceService.shared.saveReminderSubtasks(reminderId: item.id, drafts: [])
        await reload()
    }
}

// MARK: - Editor Sheet

enum ReminderEditorMode {
    case create
    case edit(CalendarService.ReminderItem)
}

enum ReminderEditorResult {
    case cancelled
    case saved(String)
    case deleted
}

struct ReminderEditorSheet: View {
    let mode: ReminderEditorMode
    let onFinish: (ReminderEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var includesTime: Bool = false
    @State private var priority: Int = 0
    @State private var notes: String = ""
    @State private var meetingInfo: String = ""
    @State private var recurrence: CalendarService.RecurrencePreset = .none
    @State private var availableLists: [CalendarService.ReminderList] = []
    @State private var selectedListId: String = ""
    @State private var subtasks: [PersistenceService.SubtaskDraft] = []
    @State private var newSubtaskTitle: String = ""
    @FocusState private var newSubtaskFocused: Bool
    @State private var labels: [String] = []
    @State private var newLabelText: String = ""
    @FocusState private var newLabelFocused: Bool
    @State private var addToCalendar: Bool = false
    @State private var eventStart: Date = Date()
    @State private var eventEnd: Date = Date().addingTimeInterval(3600)
    @State private var eventLocation: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(0)
                        Text("Low").tag(9)
                        Text("Medium").tag(5)
                        Text("High").tag(1)
                    }
                    if availableLists.count > 1 {
                        Picker("List", selection: $selectedListId) {
                            ForEach(availableLists) { list in
                                Text(list.title).tag(list.id)
                            }
                        }
                    }
                }

                Section("Due") {
                    Toggle("Has due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: includesTime ? [.date, .hourAndMinute] : .date)
                        Toggle("Include time", isOn: $includesTime)
                    }
                }

                Section {
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(CalendarService.RecurrencePreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                } header: {
                    Label("Repeat", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    if recurrence != .none {
                        Text("Completing this reminder will advance it to the next \(recurrence.label.lowercased()) occurrence.")
                    }
                }

                Section {
                    ForEach($subtasks) { $row in
                        HStack(spacing: AxisSpacing.sm) {
                            Button {
                                row.isCompleted.toggle()
                            } label: {
                                Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(row.isCompleted ? Color.axisAccent : .secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Subtask", text: $row.title)
                                .strikethrough(row.isCompleted)
                                .foregroundStyle(row.isCompleted ? .secondary : .primary)
                        }
                    }
                    .onDelete { indexSet in
                        subtasks.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        subtasks.move(fromOffsets: from, toOffset: to)
                        renumberSubtasks()
                    }
                    HStack(spacing: AxisSpacing.sm) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.axisAccent)
                        TextField("Add subtask", text: $newSubtaskTitle)
                            .focused($newSubtaskFocused)
                            .submitLabel(.done)
                            .onSubmit(addSubtask)
                        if !newSubtaskTitle.isEmpty {
                            Button("Add", action: addSubtask)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisAccent)
                        }
                    }
                } header: {
                    Label("Subtasks", systemImage: "checklist")
                } footer: {
                    if !subtasks.isEmpty {
                        let done = subtasks.filter(\.isCompleted).count
                        Text("\(done) of \(subtasks.count) complete")
                    }
                }

                Section {
                    if !labels.isEmpty {
                        labelChipsFlow
                    }
                    HStack(spacing: AxisSpacing.sm) {
                        Image(systemName: "number")
                            .foregroundStyle(Color.axisAccent)
                        TextField("Add label", text: $newLabelText)
                            .focused($newLabelFocused)
                            .submitLabel(.done)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit(addLabel)
                        if !newLabelText.isEmpty {
                            Button("Add", action: addLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisAccent)
                        }
                    }
                } header: {
                    Label("Labels", systemImage: "tag")
                } footer: {
                    Text("Tags sync to Apple Reminders so you can filter by them in the system app too.")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Anything extra you want attached to the reminder.")
                }

                Section {
                    TextField("Zoom / Teams link, meeting ID, passcode, dial-in…", text: $meetingInfo, axis: .vertical)
                        .lineLimit(3...10)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Label("Meeting Info", systemImage: "video")
                } footer: {
                    Text("Paste join links and credentials here. Axis will detect Zoom/Teams/Meet URLs and show a one-tap Join button on events you create from this reminder.")
                }

                Section {
                    Toggle("Add to Calendar", isOn: $addToCalendar)
                    if addToCalendar {
                        DatePicker("Starts", selection: $eventStart, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Ends", selection: $eventEnd, displayedComponents: [.date, .hourAndMinute])
                        TextField("Location", text: $eventLocation)
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    if addToCalendar {
                        Text("Creates a paired calendar event. The event's notes include the meeting info above, so the Join button surfaces automatically.")
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            delete()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onFinish(.cancelled)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private func hydrate() {
        availableLists = CalendarService.shared.availableReminderLists()
        switch mode {
        case .create:
            title = ""
            hasDueDate = false
            includesTime = false
            priority = 0
            notes = ""
            meetingInfo = ""
            recurrence = .none
            subtasks = []
            newSubtaskTitle = ""
            labels = []
            newLabelText = ""
            selectedListId = availableLists.first(where: \.isDefault)?.id ?? availableLists.first?.id ?? ""
            addToCalendar = false
            eventStart = Date()
            eventEnd = Date().addingTimeInterval(3600)
            eventLocation = ""
        case .edit(let item):
            title = item.title
            hasDueDate = item.dueDate != nil
            dueDate = item.dueDate ?? Date()
            includesTime = item.hasDueTime
            priority = item.priority
            if let details = CalendarService.shared.reminderDetails(id: item.id) {
                notes = details.notes ?? ""
                meetingInfo = details.meetingInfo ?? ""
            }
            recurrence = CalendarService.shared.reminderRecurrence(id: item.id)
            subtasks = PersistenceService.shared.fetchSubtasks(forReminder: item.id).map {
                PersistenceService.SubtaskDraft(
                    id: $0.uuid,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    sortOrder: $0.sortOrder
                )
            }
            newSubtaskTitle = ""
            labels = CalendarService.shared.reminderLabels(id: item.id)
            newLabelText = ""
            selectedListId = item.calendarIdentifier
                ?? availableLists.first(where: \.isDefault)?.id
                ?? availableLists.first?.id
                ?? ""
            addToCalendar = false
            eventStart = item.dueDate ?? Date()
            eventEnd = (item.dueDate ?? Date()).addingTimeInterval(3600)
            eventLocation = ""
        }
    }

    @ViewBuilder
    private var labelChipsFlow: some View {
        // Flexible row that wraps using a horizontal stack inside a ScrollView.
        // A real flow layout is overkill for handful-of-tags case.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AxisSpacing.xs) {
                ForEach(labels, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                        Button {
                            labels.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.axisAccent.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.axisAccent.opacity(0.15)))
                    .foregroundStyle(Color.axisAccent)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func addLabel() {
        guard let cleaned = AxisReminderNotes.normalizeLabel(newLabelText) else { return }
        if !labels.contains(cleaned) {
            labels.append(cleaned)
        }
        newLabelText = ""
        newLabelFocused = true
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(.init(
            id: UUID(),
            title: trimmed,
            isCompleted: false,
            sortOrder: subtasks.count
        ))
        newSubtaskTitle = ""
        newSubtaskFocused = true
    }

    private func renumberSubtasks() {
        for index in subtasks.indices {
            subtasks[index].sortOrder = index
        }
    }

    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let id: String?
        let chosenList = selectedListId.isEmpty ? nil : selectedListId
        switch mode {
        case .create:
            id = CalendarService.shared.createReminder(
                title: cleaned,
                notes: notes.isEmpty ? nil : notes,
                meetingInfo: meetingInfo.isEmpty ? nil : meetingInfo,
                dueDate: hasDueDate ? dueDate : nil,
                includeDueTime: includesTime,
                priority: priority,
                recurrence: recurrence,
                calendarIdentifier: chosenList,
                labels: labels
            )
        case .edit(let item):
            let ok = CalendarService.shared.updateReminder(
                id: item.id,
                title: cleaned,
                notes: notes,
                meetingInfo: meetingInfo,
                dueDate: hasDueDate ? dueDate : nil,
                clearDueDate: !hasDueDate,
                includeDueTime: includesTime,
                priority: priority,
                recurrence: recurrence,
                calendarIdentifier: chosenList,
                labels: labels
            )
            id = ok ? item.id : nil
        }

        if let finalId = id {
            renumberSubtasks()
            PersistenceService.shared.saveReminderSubtasks(reminderId: finalId, drafts: subtasks)
        }

        if addToCalendar, let finalId = id {
            _ = CalendarService.shared.createEventFromReminder(
                title: cleaned,
                startDate: eventStart,
                endDate: eventEnd > eventStart ? eventEnd : eventStart.addingTimeInterval(3600),
                location: eventLocation.isEmpty ? nil : eventLocation,
                notes: notes.isEmpty ? nil : notes,
                meetingInfo: meetingInfo.isEmpty ? nil : meetingInfo
            )
            onFinish(.saved(finalId))
        } else if let finalId = id {
            onFinish(.saved(finalId))
        } else {
            onFinish(.cancelled)
        }
        dismiss()
    }

    private func delete() {
        if case let .edit(item) = mode {
            _ = CalendarService.shared.deleteReminder(id: item.id)
        }
        onFinish(.deleted)
        dismiss()
    }
}

// MARK: - Inline Date Picker Sheet

private struct InlineDatePickerSheet: View {
    let reminder: CalendarService.ReminderItem
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Date()
    @State private var includesTime: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Has due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Date",
                            selection: $dueDate,
                            displayedComponents: includesTime ? [.date, .hourAndMinute] : .date
                        )
                        .datePickerStyle(.graphical)
                        Toggle("Include time", isOn: $includesTime)
                    }
                } header: {
                    Text(reminder.title).font(.headline).foregroundStyle(.primary)
                }
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                dueDate = reminder.dueDate ?? Date()
                hasDueDate = reminder.dueDate != nil
                includesTime = reminder.hasDueTime
            }
        }
    }

    private func save() {
        _ = CalendarService.shared.updateReminder(
            id: reminder.id,
            dueDate: hasDueDate ? dueDate : nil,
            clearDueDate: !hasDueDate,
            includeDueTime: includesTime
        )
        onSaved()
        dismiss()
    }
}
