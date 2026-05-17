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

    /// High-level display mode for the Workflow tab.
    enum ViewMode: String, CaseIterable, Identifiable {
        case list, week, calendar, board
        var id: String { rawValue }
        var label: String {
            switch self {
            case .list: return "List"
            case .week: return "Week"
            case .calendar: return "Calendar"
            case .board: return "Board"
            }
        }
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .week: return "calendar.day.timeline.left"
            case .calendar: return "calendar"
            case .board: return "rectangle.split.3x1"
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
    @State private var showKarma = false
    @State private var showCommandPalette = false
    @State private var newQuickTitle = ""
    @FocusState private var quickFocused: Bool
    @AppStorage("workflow.grouping") private var grouping: Grouping = .date
    @AppStorage("workflow.todaySubGroup") private var todaySubGroup: TodaySubGroup = .time
    @AppStorage("workflow.viewMode") private var viewMode: ViewMode = .list
    @State private var filter: ReminderFilter = .none

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch vm.state {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .denied:
                        deniedState
                    case .loaded:
                        switch viewMode {
                        case .list: loadedList
                        case .week: WeekScrollView(
                            vm: vm,
                            onSelect: { selectedReminder = $0 },
                            onReschedule: { inlineDateReminder = $0 }
                        )
                        case .calendar: TasksCalendarView(
                            vm: vm,
                            onSelect: { selectedReminder = $0 },
                            onReschedule: { inlineDateReminder = $0 }
                        )
                        case .board: BoardView(
                            vm: vm,
                            onSelect: { selectedReminder = $0 },
                            onReschedule: { inlineDateReminder = $0 }
                        )
                        }
                    }
                }
                // Things signature: floating cobalt + button. Sits in the
                // bottom-right of every Workflow view mode.
                if case .loaded = vm.state {
                    MagicPlusButton {
                        showAddSheet = true
                    }
                    .padding(.trailing, AxisSpacing.lg)
                    .padding(.bottom, AxisSpacing.lg)
                }
            }
            .background(Color.axisCream.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("View", selection: $viewMode) {
                            ForEach(ViewMode.allCases) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        Divider()
                        Picker("Group", selection: $grouping) {
                            ForEach(Grouping.allCases) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        if grouping == .date && viewMode == .list {
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
                    Button { showCommandPalette = true } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showKarma = true } label: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                    }
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
            .sheet(isPresented: $showKarma) {
                KarmaView()
            }
            .sheet(isPresented: $showCommandPalette) {
                CommandPaletteSheet(
                    vm: vm,
                    onOpenReminder: { item in
                        showCommandPalette = false
                        selectedReminder = item
                    },
                    onSelectFilter: { newFilter in
                        showCommandPalette = false
                        filter = newFilter
                    },
                    onSelectAction: { action in
                        showCommandPalette = false
                        switch action {
                        case .newReminder: showAddSheet = true
                        case .openKarma: showKarma = true
                        case .quickAdd: quickFocused = true
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            // Things-style hero header — yellow star icon + "Today" title +
            // today's date subtitle. Replaces the legacy gold serif nav title.
            Section {
                ThingsHeroHeader(
                    title: heroTitle,
                    subtitle: heroSubtitle,
                    icon: heroIcon,
                    color: heroIconColor
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
            }
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Hero header content
    private var heroTitle: String {
        switch filter {
        case .none: return "Today"
        case .pinnedOnly: return "Pinned"
        case .overdueOnly: return "Overdue"
        case .noDateOnly: return "No Date"
        case .todayHighPriority: return "Today + High"
        case .highPriorityOnly: return "High Priority"
        case .label(let l): return "#\(l)"
        case .priority: return "By Priority"
        case .list(let id): return vm.allLists.first(where: { $0.id == id })?.title ?? "List"
        }
    }
    private var heroSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
    private var heroIcon: String {
        switch filter {
        case .none: return "star.fill"
        case .pinnedOnly: return "pin.fill"
        case .overdueOnly: return "exclamationmark.triangle.fill"
        case .noDateOnly: return "calendar.badge.minus"
        case .todayHighPriority: return "sparkles"
        case .highPriorityOnly: return "flag.fill"
        case .label: return "number"
        case .priority: return "flag.fill"
        case .list: return "list.bullet.rectangle"
        }
    }
    private var heroIconColor: Color {
        switch filter {
        case .none: return .axisYellowTone
        case .pinnedOnly: return .axisOrangeTone
        case .overdueOnly: return .axisRedTone
        case .noDateOnly: return .axisInkMute
        case .todayHighPriority: return .axisPurpleTone
        case .highPriorityOnly: return .axisRedTone
        case .label: return .axisCobalt
        case .priority: return .axisRedTone
        case .list: return .axisCobalt
        }
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
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.axisInk)
                    Spacer()
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundStyle(Color.axisInkMute)
                }
                .textCase(nil)
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
        let wasCompleted = subtask.isCompleted
        subtask.isCompleted.toggle()
        PersistenceService.shared.updateSubtasks()
        if !wasCompleted {
            CompletionTracker.recordCompletion()
        }
        Task { await reload() }
    }

    func toggleComplete(_ item: CalendarService.ReminderItem) async {
        if item.isCompleted {
            _ = CalendarService.shared.uncompleteReminder(id: item.id)
        } else {
            _ = CalendarService.shared.completeReminder(id: item.id)
            CompletionTracker.recordCompletion()
        }
        await reload()
    }

    func recordSubtaskCompletion() {
        CompletionTracker.recordCompletion()
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
    @State private var showTemplatePicker = false
    @State private var showSaveTemplate = false
    @State private var newTemplateName = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section {
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("Use a Template…", systemImage: "doc.text.below.ecg")
                                .foregroundStyle(Color.axisAccent)
                        }
                    }
                }
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

                Section {
                    Button {
                        newTemplateName = title.isEmpty ? "Untitled template" : title
                        showSaveTemplate = true
                    } label: {
                        Label("Save as Template…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .sheet(isPresented: $showTemplatePicker) {
                ReminderTemplatePicker { template in
                    apply(template)
                }
            }
            .alert("Save as Template", isPresented: $showSaveTemplate) {
                TextField("Template name", text: $newTemplateName)
                Button("Save") { saveAsTemplate() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Captures title, priority, labels, and subtasks.")
            }
            .onAppear(perform: hydrate)
        }
    }

    private func apply(_ template: ReminderTemplate) {
        title = template.titlePattern
        priority = template.priority
        labels = template.labels
        subtasks = template.subtasks.enumerated().map { idx, sub in
            PersistenceService.SubtaskDraft(
                id: UUID(),
                title: sub,
                isCompleted: false,
                sortOrder: idx
            )
        }
        if let id = template.calendarIdentifier,
           availableLists.contains(where: { $0.id == id }) {
            selectedListId = id
        }
        if let offset = template.dueOffsetDays,
           let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) {
            hasDueDate = true
            dueDate = date
        }
    }

    private func saveAsTemplate() {
        let cleanedName = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let offset: Int? = hasDueDate
            ? Calendar.current.dateComponents([.day],
                                              from: Calendar.current.startOfDay(for: Date()),
                                              to: Calendar.current.startOfDay(for: dueDate)).day
            : nil
        let template = ReminderTemplate(
            name: cleanedName,
            titlePattern: cleanedTitle,
            priority: priority,
            labels: labels,
            subtasks: subtasks.map(\.title).filter { !$0.isEmpty },
            calendarIdentifier: selectedListId.isEmpty ? nil : selectedListId,
            dueOffsetDays: offset
        )
        var all = ReminderTemplateStore.loadAll()
        all.append(template)
        ReminderTemplateStore.saveAll(all)
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
    @State private var recurrence: CalendarService.RecurrencePreset = .none

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
                recurrence = CalendarService.shared.reminderRecurrence(id: reminder.id)
            }
        }
    }

    private func save() {
        _ = CalendarService.shared.updateReminder(
            id: reminder.id,
            dueDate: hasDueDate ? dueDate : nil,
            clearDueDate: !hasDueDate,
            includeDueTime: includesTime,
            recurrence: recurrence
        )
        onSaved()
        dismiss()
    }
}

// MARK: - Templates

struct ReminderTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String                // user-facing name e.g. "Weekly 1:1 prep"
    var titlePattern: String        // becomes the reminder title (free text)
    var priority: Int = 0
    var labels: [String] = []
    var subtasks: [String] = []     // ordered subtask titles
    var calendarIdentifier: String? = nil
    /// Number of days from "now" to set as the default due date when
    /// instantiating. nil = no due date. 0 = today.
    var dueOffsetDays: Int? = nil
}

/// File-private store so templates can be edited without crossing target boundaries.
enum ReminderTemplateStore {
    private static let key = "workflow.templates.v1"

    static func loadAll() -> [ReminderTemplate] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ReminderTemplate].self, from: data) else {
            return seeded
        }
        return decoded
    }

    static func saveAll(_ templates: [ReminderTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Built-in starter templates the user gets the first time they open
    /// the picker. Easy to delete or override; we don't re-seed once the
    /// store has been written.
    static let seeded: [ReminderTemplate] = [
        ReminderTemplate(
            name: "Weekly 1:1 Prep",
            titlePattern: "1:1 prep",
            priority: 5,
            labels: ["work"],
            subtasks: ["Wins from last week", "Blockers", "Topics for this week", "Asks"],
            dueOffsetDays: 0
        ),
        ReminderTemplate(
            name: "Trip Packing",
            titlePattern: "Pack for trip",
            priority: 5,
            labels: ["travel"],
            subtasks: ["Charger", "Toiletries", "Clothes", "ID / passport", "Snacks"],
            dueOffsetDays: 1
        ),
        ReminderTemplate(
            name: "Weekly Review",
            titlePattern: "Weekly review",
            priority: 5,
            labels: ["personal"],
            subtasks: ["Clear inbox", "Process notes", "Plan next week", "Celebrate one win"],
            dueOffsetDays: 7
        )
    ]
}

// MARK: - Karma / Completion tracking

/// Tracks one completion per reminder per day. Used for streaks, weekly
/// chart, and lifetime totals.
enum CompletionTracker {
    private static let key = "workflow.completions.v1"
    private static let calendar = Calendar.current
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Recorded counts keyed by yyyy-MM-dd string.
    private static func load() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private static func write(_ map: [String: Int]) {
        UserDefaults.standard.set(map, forKey: key)
    }

    static func recordCompletion(on date: Date = Date()) {
        var map = load()
        let key = dayFormatter.string(from: date)
        map[key, default: 0] += 1
        write(map)
    }

    static func todayCount() -> Int {
        let key = dayFormatter.string(from: Date())
        return load()[key] ?? 0
    }

    static func allTimeTotal() -> Int {
        load().values.reduce(0, +)
    }

    /// Number of consecutive days ending today (inclusive) that have at
    /// least one completion.
    static func currentStreak() -> Int {
        let map = load()
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while true {
            let key = dayFormatter.string(from: cursor)
            if (map[key] ?? 0) > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }
        return streak
    }

    struct DailyBar: Identifiable {
        let id: Date
        let date: Date
        let count: Int
        var label: String {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
    }

    /// Last `n` days (default 7), oldest first.
    static func lastDays(_ n: Int = 7) -> [DailyBar] {
        let map = load()
        let today = calendar.startOfDay(for: Date())
        var bars: [DailyBar] = []
        for offset in stride(from: n - 1, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = dayFormatter.string(from: d)
            bars.append(DailyBar(id: d, date: d, count: map[key] ?? 0))
        }
        return bars
    }
}

// MARK: - Karma Dashboard

struct KarmaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bars: [CompletionTracker.DailyBar] = []
    @State private var todayCount: Int = 0
    @State private var streak: Int = 0
    @State private var total: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.lg) {
                    statTiles
                    chartCard
                    achievementsCard
                    streakCard
                }
                .padding(AxisSpacing.lg)
            }
            .background(Color.axisBackground.ignoresSafeArea())
            .navigationTitle("Karma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        bars = CompletionTracker.lastDays(7)
        todayCount = CompletionTracker.todayCount()
        streak = CompletionTracker.currentStreak()
        total = CompletionTracker.allTimeTotal()
    }

    private var statTiles: some View {
        HStack(spacing: AxisSpacing.md) {
            statTile(title: "Today", value: "\(todayCount)", icon: "checkmark.circle.fill", tint: Color.axisAccent)
            statTile(title: "Streak", value: "\(streak)", icon: "flame.fill", tint: .orange)
            statTile(title: "Lifetime", value: "\(total)", icon: "infinity", tint: Color.axisInfo)
        }
    }

    private func statTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AxisSpacing.md)
        .axisCard()
    }

    /// 7-day mini chart kept as a sparkline above the heat map for quick read.
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack {
                Text("Last 7 Days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(bars.map(\.count).reduce(0, +)) completions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let maxCount = max(1, bars.map(\.count).max() ?? 1)
            HStack(alignment: .bottom, spacing: AxisSpacing.xs) {
                ForEach(bars) { bar in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.axisHairline)
                                .frame(height: 60)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.axisCobalt)
                                .frame(height: CGFloat(bar.count) / CGFloat(maxCount) * 60)
                        }
                        Text(bar.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            heatmapStrip
        }
        .thingsCard(padding: AxisSpacing.md)
    }

    /// Full-year GitHub-style heat map of every day's completions. Scrolls
    /// horizontally so all 52 weeks fit on phone screens.
    private var heatmapStrip: some View {
        let days = CompletionTracker.lastDays(364)
        let weeks: [[CompletionTracker.DailyBar]] = stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
        let maxCount = max(1, days.map(\.count).max() ?? 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let streakLength = CompletionTracker.currentStreak()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Last 12 months")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text("Less").font(.caption2).foregroundStyle(.secondary)
                    ForEach(0..<5, id: \.self) { tier in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(for: tier, of: 4))
                            .frame(width: 10, height: 10)
                    }
                    Text("More").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, AxisSpacing.sm)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                            VStack(spacing: 3) {
                                ForEach(week) { day in
                                    let isToday = cal.isDate(day.date, inSameDayAs: today)
                                    let inStreak = streakLength > 0 &&
                                        day.date >= cal.date(byAdding: .day, value: -(streakLength - 1), to: today)!
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(heatColor(for: tier(of: day.count, max: maxCount), of: 4))
                                        .frame(width: 11, height: 11)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .strokeBorder(
                                                    isToday ? Color.axisCobalt :
                                                    (inStreak && day.count > 0 ? Color.axisYellowTone : Color.clear),
                                                    lineWidth: isToday ? 1.5 : (inStreak ? 1 : 0)
                                                )
                                        )
                                }
                                // Pad short weeks at the end so columns align.
                                if week.count < 7 {
                                    ForEach(0..<(7 - week.count), id: \.self) { _ in
                                        Color.clear.frame(width: 11, height: 11)
                                    }
                                }
                            }
                            .id(idx)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    // Scroll to today (last column).
                    DispatchQueue.main.async {
                        proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                    }
                }
            }
        }
    }

    private func tier(of count: Int, max: Int) -> Int {
        guard count > 0 else { return 0 }
        let ratio = Double(count) / Double(max)
        if ratio > 0.75 { return 4 }
        if ratio > 0.45 { return 3 }
        if ratio > 0.20 { return 2 }
        return 1
    }

    private func heatColor(for tier: Int, of maxTier: Int) -> Color {
        switch tier {
        case 0: return Color.axisHairline
        case 1: return Color.axisCobalt.opacity(0.22)
        case 2: return Color.axisCobalt.opacity(0.48)
        case 3: return Color.axisCobalt.opacity(0.75)
        default: return Color.axisCobalt
        }
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack {
                Text("Achievements")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(AchievementsStore.unlocked(streak: streak, total: total, todayCount: todayCount, bars: bars).count)/\(AchievementsStore.all.count) unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let unlocked = AchievementsStore.unlocked(
                streak: streak, total: total, todayCount: todayCount, bars: bars
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AchievementsStore.all) { a in
                        AchievementBadge(achievement: a, unlocked: unlocked.contains(a.id))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .thingsCard(padding: AxisSpacing.md)
    }

    private var streakCard: some View {
        HStack(spacing: AxisSpacing.md) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 32))
                .foregroundStyle(streak > 0 ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak > 0 ? "You're on fire" : "Start a streak today")
                    .font(.headline)
                Text(streak > 0
                     ? "Complete at least one reminder tomorrow to keep \(streak)-day streak alive."
                     : "Complete any reminder today to start a streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AxisSpacing.md)
        .axisCard()
    }
}

// MARK: - Compact Reminder Card
//
// Card-style row used by the Week / Calendar / Board views. Lighter than
// the main ReminderRow because these views need to fit more density.

private struct ReminderCard: View {
    let item: CalendarService.ReminderItem
    let accent: Color
    let isPinned: Bool
    let onToggle: () async -> Void
    let onTap: () -> Void
    let onTapDate: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: AxisSpacing.sm) {
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isCompleted ? accent : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted)
                        .lineLimit(2)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 6) {
                    if let due = item.dueDate {
                        Button {
                            onTapDate?()
                        } label: {
                            Text(shortDue(due, includesTime: item.hasDueTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if item.priority > 0 && item.priority <= 3 {
                        Text("HIGH")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.axisDanger.opacity(0.18)))
                            .foregroundStyle(Color.axisDanger)
                    }
                    if let list = item.calendarTitle {
                        Text(list)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AxisSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.axisSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.axisDivider.opacity(0.3), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private func shortDue(_ date: Date, includesTime: Bool) -> String {
        let f = DateFormatter()
        if includesTime {
            f.dateFormat = "MMM d · h:mm a"
        } else {
            f.dateFormat = "MMM d"
        }
        return f.string(from: date)
    }
}

// MARK: - Week Scroll View

/// Vertically scrolling next-7-days view. Each day is its own section
/// with a header showing the day name, date, and item count.
private struct WeekScrollView: View {
    let vm: RemindersViewModel
    let onSelect: (CalendarService.ReminderItem) -> Void
    let onReschedule: (CalendarService.ReminderItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.lg) {
                ForEach(days, id: \.id) { day in
                    section(for: day)
                }
                if !overdue.isEmpty {
                    overdueSection
                }
            }
            .padding(AxisSpacing.lg)
        }
        .background(Color.axisBackground.ignoresSafeArea())
    }

    private struct Day: Identifiable {
        let id: Date
        let date: Date
        let items: [CalendarService.ReminderItem]
    }

    private var days: [Day] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let all = vm.today + vm.upcoming
        var result: [Day] = []
        for offset in 0..<7 {
            guard let dayStart = cal.date(byAdding: .day, value: offset, to: start),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let bucket = all.filter { item in
                guard let due = item.dueDate else { return false }
                return due >= dayStart && due < dayEnd
            }
            result.append(Day(id: dayStart, date: dayStart, items: bucket.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }))
        }
        return result
    }

    private var overdue: [CalendarService.ReminderItem] { vm.overdue }

    @ViewBuilder
    private func section(for day: Day) -> some View {
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack(spacing: AxisSpacing.sm) {
                Text(dayHeader(day.date))
                    .font(.headline)
                Text(dateSubheader(day.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(day.items.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.axisAccent.opacity(0.15)))
                    .foregroundStyle(Color.axisAccent)
            }
            if day.items.isEmpty {
                Text("Nothing scheduled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, AxisSpacing.xs)
            } else {
                ForEach(day.items) { item in
                    ReminderCard(
                        item: item,
                        accent: Color.axisAccent,
                        isPinned: vm.isPinnedToday(item.id),
                        onToggle: { await vm.toggleComplete(item) },
                        onTap: { onSelect(item) },
                        onTapDate: { onReschedule(item) }
                    )
                }
            }
        }
    }

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack {
                Text("Overdue")
                    .font(.headline)
                    .foregroundStyle(Color.axisDanger)
                Spacer()
                Text("\(overdue.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.axisDanger.opacity(0.15)))
                    .foregroundStyle(Color.axisDanger)
            }
            ForEach(overdue) { item in
                ReminderCard(
                    item: item,
                    accent: Color.axisDanger,
                    isPinned: vm.isPinnedToday(item.id),
                    onToggle: { await vm.toggleComplete(item) },
                    onTap: { onSelect(item) },
                    onTapDate: { onReschedule(item) }
                )
            }
        }
    }

    private func dayHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func dateSubheader(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Calendar View

/// Month grid of dots-per-day. Tap a day to scroll a list of that day's
/// reminders underneath. Includes month-navigation controls.
private struct TasksCalendarView: View {
    let vm: RemindersViewModel
    let onSelect: (CalendarService.ReminderItem) -> Void
    let onReschedule: (CalendarService.ReminderItem) -> Void

    @State private var monthStart: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            VStack(spacing: AxisSpacing.lg) {
                header
                grid
                dayDetail
            }
            .padding(AxisSpacing.lg)
        }
        .background(Color.axisBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.title3)
            }
            Spacer()
            Text(monthLabel(monthStart))
                .font(.title3.weight(.semibold))
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.title3)
            }
        }
        .foregroundStyle(Color.axisAccent)
    }

    private func shiftMonth(_ by: Int) {
        if let m = Calendar.current.date(byAdding: .month, value: by, to: monthStart) {
            monthStart = m
        }
    }

    private var grid: some View {
        let cal = Calendar.current
        let weekdaySymbols = cal.shortStandaloneWeekdaySymbols
        let days = monthDays()
        return VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.id) { cell in
                    dayCell(cell)
                }
            }
        }
        .padding(AxisSpacing.md)
        .axisCard()
    }

    private struct DayCell: Identifiable {
        let id: Date
        let date: Date
        let inMonth: Bool
        let count: Int
    }

    private func monthDays() -> [DayCell] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<30
        let monthFirst = cal.date(from: cal.dateComponents([.year, .month], from: monthStart)) ?? monthStart
        let leading = cal.component(.weekday, from: monthFirst) - 1
        var cells: [DayCell] = []
        // Leading filler from prev month.
        for offset in stride(from: leading, to: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -offset, to: monthFirst) {
                cells.append(DayCell(id: d, date: d, inMonth: false, count: count(on: d)))
            }
        }
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthFirst) {
                cells.append(DayCell(id: d, date: d, inMonth: true, count: count(on: d)))
            }
        }
        // Trailing filler to fill final week.
        let remainder = (7 - cells.count % 7) % 7
        if remainder > 0, let lastInMonth = cal.date(byAdding: .day, value: range.count - 1, to: monthFirst) {
            for offset in 1...remainder {
                if let d = cal.date(byAdding: .day, value: offset, to: lastInMonth) {
                    cells.append(DayCell(id: d, date: d, inMonth: false, count: count(on: d)))
                }
            }
        }
        return cells
    }

    private func count(on date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let all = vm.today + vm.upcoming + vm.overdue
        return all.filter { item in
            guard let due = item.dueDate else { return false }
            return due >= start && due < end
        }.count
    }

    @ViewBuilder
    private func dayCell(_ cell: DayCell) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(cell.date, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(cell.date)
        Button {
            selectedDay = cal.startOfDay(for: cell.date)
        } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: cell.date))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(cellForeground(inMonth: cell.inMonth, isSelected: isSelected, isToday: isToday))
                Circle()
                    .fill(cell.count > 0 ? Color.axisAccent : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.axisAccent.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.axisAccent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cellForeground(inMonth: Bool, isSelected: Bool, isToday: Bool) -> Color {
        if !inMonth { return Color.secondary.opacity(0.5) }
        if isSelected || isToday { return Color.axisAccent }
        return Color.primary
    }

    @ViewBuilder
    private var dayDetail: some View {
        let items = itemsOn(selectedDay)
        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack {
                Text(detailHeader(selectedDay))
                    .font(.headline)
                Spacer()
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                Text("Nothing scheduled this day.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items) { item in
                    ReminderCard(
                        item: item,
                        accent: Color.axisAccent,
                        isPinned: vm.isPinnedToday(item.id),
                        onToggle: { await vm.toggleComplete(item) },
                        onTap: { onSelect(item) },
                        onTapDate: { onReschedule(item) }
                    )
                }
            }
        }
    }

    private func itemsOn(_ date: Date) -> [CalendarService.ReminderItem] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let all = vm.today + vm.upcoming + vm.overdue
        return all.filter { item in
            guard let due = item.dueDate else { return false }
            return due >= start && due < end
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func detailHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - Board / Kanban View

/// Horizontally scrolling Kanban — one column per Reminders list. Each
/// column scrolls vertically and shows compact cards.
private struct BoardView: View {
    let vm: RemindersViewModel
    let onSelect: (CalendarService.ReminderItem) -> Void
    let onReschedule: (CalendarService.ReminderItem) -> Void

    @State private var dropTargetId: String? = nil

    private struct Column: Identifiable {
        /// Backing list identifier (EKCalendar id). Items without a known
        /// identifier are bucketed under id == "".
        let id: String
        let title: String
        let items: [CalendarService.ReminderItem]
    }

    private var columns: [Column] {
        let all = vm.overdue + vm.today + vm.upcoming + vm.undated
        // Group by stable identifier so titles that happen to collide (e.g.
        // two accounts each with "Reminders") stay in separate columns and
        // drops always know which calendar to land in.
        let grouped = Dictionary(grouping: all) { $0.calendarIdentifier ?? "" }
        let titleById = Dictionary(uniqueKeysWithValues: vm.allLists.map { ($0.id, $0.title) })
        return grouped
            .map { (key, items) in
                let title = titleById[key] ?? items.first?.calendarTitle ?? "Reminders"
                return Column(id: key, title: title, items: items.sorted {
                    ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
                })
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: AxisSpacing.md) {
                ForEach(columns) { column in
                    columnView(column)
                }
            }
            .padding(AxisSpacing.md)
        }
        .background(Color.axisBackground.ignoresSafeArea())
    }

    private func columnView(_ column: Column) -> some View {
        let isTargeted = dropTargetId == column.id
        return VStack(alignment: .leading, spacing: AxisSpacing.sm) {
            HStack {
                Text(column.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(column.items.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.axisAccent.opacity(0.15)))
                    .foregroundStyle(Color.axisAccent)
            }
            .padding(.horizontal, AxisSpacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.sm) {
                    if column.items.isEmpty {
                        Text("Drop here")
                            .font(.caption)
                            .foregroundStyle(Color.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AxisSpacing.xl)
                    } else {
                        ForEach(column.items) { item in
                            ReminderCard(
                                item: item,
                                accent: Color.axisAccent,
                                isPinned: vm.isPinnedToday(item.id),
                                onToggle: { await vm.toggleComplete(item) },
                                onTap: { onSelect(item) },
                                onTapDate: { onReschedule(item) }
                            )
                            .draggable(item.id)
                        }
                    }
                }
                .padding(AxisSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTargeted ? Color.axisAccent.opacity(0.22) : Color.axisDivider.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isTargeted ? Color.axisAccent : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { ids, _ in
            handleDrop(ids: ids, column: column)
        } isTargeted: { targeted in
            dropTargetId = targeted ? column.id : nil
        }
    }

    private func handleDrop(ids: [String], column: Column) -> Bool {
        guard let droppedId = ids.first, !column.id.isEmpty else { return false }
        // Only move if it's actually changing column.
        if let item = vm.byId[droppedId], item.calendarIdentifier == column.id {
            return false
        }
        _ = CalendarService.shared.updateReminder(
            id: droppedId,
            calendarIdentifier: column.id
        )
        Task { await vm.reload() }
        return true
    }
}

// MARK: - Template Picker Sheet

struct ReminderTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onChoose: (ReminderTemplate) -> Void
    @State private var templates: [ReminderTemplate] = []
    @State private var editing: ReminderTemplate?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if templates.isEmpty {
                        Text("No templates yet. Tap + to add one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates) { template in
                            HStack(alignment: .top) {
                                Button {
                                    onChoose(template)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(template.titlePattern)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if !template.subtasks.isEmpty {
                                            Text("\(template.subtasks.count) subtasks")
                                                .font(.caption)
                                                .foregroundStyle(Color.secondary.opacity(0.6))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button {
                                    editing = template
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .font(.title3)
                                        .foregroundStyle(Color.axisAccent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { offsets in
                            templates.remove(atOffsets: offsets)
                            ReminderTemplateStore.saveAll(templates)
                        }
                    }
                } header: {
                    Text("Templates")
                } footer: {
                    Text("Tap to apply. Pencil to edit. Swipe to delete.")
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisAccent)
                    }
                }
            }
            .sheet(item: $editing) { template in
                TemplateEditorSheet(template: template) { updated in
                    if let idx = templates.firstIndex(where: { $0.id == updated.id }) {
                        templates[idx] = updated
                        ReminderTemplateStore.saveAll(templates)
                    }
                    editing = nil
                } onDelete: {
                    templates.removeAll { $0.id == template.id }
                    ReminderTemplateStore.saveAll(templates)
                    editing = nil
                }
            }
            .sheet(isPresented: $showNew) {
                TemplateEditorSheet(template: ReminderTemplate(name: "", titlePattern: "")) { created in
                    templates.append(created)
                    ReminderTemplateStore.saveAll(templates)
                    showNew = false
                } onDelete: {
                    showNew = false
                }
            }
            .onAppear { templates = ReminderTemplateStore.loadAll() }
        }
    }
}

// MARK: - Template Editor

struct TemplateEditorSheet: View {
    let template: ReminderTemplate
    let onSave: (ReminderTemplate) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var titlePattern: String = ""
    @State private var priority: Int = 0
    @State private var labelsText: String = ""
    @State private var subtasksText: String = ""
    @State private var hasDueOffset: Bool = false
    @State private var dueOffsetDays: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name (e.g. Weekly 1:1 Prep)", text: $name)
                    TextField("Reminder title", text: $titlePattern)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(0)
                        Text("Low").tag(9)
                        Text("Medium").tag(5)
                        Text("High").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("comma, separated, labels", text: $labelsText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Label("Labels", systemImage: "tag")
                } footer: {
                    Text("Each label becomes a #tag synced to Apple Reminders.")
                }

                Section {
                    TextField("One subtask per line", text: $subtasksText, axis: .vertical)
                        .lineLimit(3...12)
                } header: {
                    Label("Subtasks", systemImage: "checklist")
                }

                Section {
                    Toggle("Default due offset", isOn: $hasDueOffset)
                    if hasDueOffset {
                        Stepper(value: $dueOffsetDays, in: 0...365) {
                            Text(offsetLabel(dueOffsetDays))
                        }
                    }
                } header: {
                    Label("Due Date", systemImage: "calendar")
                } footer: {
                    Text("When applied, the reminder's due date will be set this many days from today.")
                }

                if !template.name.isEmpty {
                    Section {
                        Button("Delete Template", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(template.name.isEmpty ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private func offsetLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days from now"
        }
    }

    private func hydrate() {
        name = template.name
        titlePattern = template.titlePattern
        priority = template.priority
        labelsText = template.labels.joined(separator: ", ")
        subtasksText = template.subtasks.joined(separator: "\n")
        if let offset = template.dueOffsetDays {
            hasDueOffset = true
            dueOffsetDays = offset
        } else {
            hasDueOffset = false
            dueOffsetDays = 0
        }
    }

    private func save() {
        let cleanedLabels = labelsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanedSubtasks = subtasksText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let updated = ReminderTemplate(
            id: template.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            titlePattern: titlePattern.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            labels: cleanedLabels,
            subtasks: cleanedSubtasks,
            calendarIdentifier: template.calendarIdentifier,
            dueOffsetDays: hasDueOffset ? dueOffsetDays : nil
        )
        onSave(updated)
        dismiss()
    }
}

// MARK: - Command Palette

/// Lightweight Spotlight-style search across reminders, smart-list filters,
/// and actions. Fires from the magnifying-glass toolbar button in Workflow.
struct CommandPaletteSheet: View {
    enum Action { case newReminder, openKarma, quickAdd }

    let vm: RemindersViewModel
    let onOpenReminder: (CalendarService.ReminderItem) -> Void
    let onSelectFilter: (WorkflowView.ReminderFilter) -> Void
    let onSelectAction: (Action) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @FocusState private var inputFocused: Bool

    private var allReminders: [CalendarService.ReminderItem] {
        vm.overdue + vm.today + vm.upcoming + vm.undated
    }

    private var matchedReminders: [CalendarService.ReminderItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        return allReminders.filter { item in
            item.title.lowercased().contains(q) ||
            (item.calendarTitle?.lowercased().contains(q) ?? false) ||
            item.labels.contains(where: { $0.lowercased().contains(q) })
        }.prefix(8).map { $0 }
    }

    private var matchedFilters: [(WorkflowView.ReminderFilter, String, String, Color)] {
        let presets: [(WorkflowView.ReminderFilter, String, String, Color)] = [
            (.none, "All Reminders", "tray.full", .axisCobalt),
            (.todayHighPriority, "Today + High Priority", "sparkles", .axisPurpleTone),
            (.overdueOnly, "Overdue", "exclamationmark.triangle.fill", .axisRedTone),
            (.noDateOnly, "No Date", "calendar.badge.minus", .axisInkMute),
            (.highPriorityOnly, "High Priority Anywhere", "flag.fill", .axisRedTone),
            (.pinnedOnly, "Pinned to Today", "pin.fill", .axisOrangeTone)
        ]
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return presets }
        let q = query.lowercased()
        return presets.filter { $0.1.lowercased().contains(q) }
    }

    private var matchedLists: [(CalendarService.ReminderList, Color)] {
        let lists = vm.allLists.map { ($0, Color.axisCobalt) }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return lists }
        let q = query.lowercased()
        return lists.filter { $0.0.title.lowercased().contains(q) }
    }

    private var matchedActions: [(Action, String, String, Color)] {
        let actions: [(Action, String, String, Color)] = [
            (.newReminder, "Create new reminder", "plus.circle.fill", .axisGreenTone),
            (.quickAdd, "Quick add (natural language)", "text.cursor", .axisCobalt),
            (.openKarma, "Open Karma & streaks", "flame.fill", .axisOrangeTone)
        ]
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return actions }
        let q = query.lowercased()
        return actions.filter { $0.1.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.axisInkMute)
                TextField("Search reminders, lists, actions…", text: $query)
                    .font(.system(size: 17))
                    .focused($inputFocused)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.axisInkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AxisSpacing.lg)
            .padding(.vertical, AxisSpacing.md)
            .background(Color.axisCream)
            .overlay(Divider(), alignment: .bottom)

            // Results
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !matchedReminders.isEmpty {
                        sectionLabel("Reminders")
                        ForEach(matchedReminders) { item in
                            row(icon: "circle", color: .axisCobalt, name: item.title,
                                meta: reminderMeta(item)) {
                                onOpenReminder(item)
                            }
                        }
                    }
                    if !matchedFilters.isEmpty {
                        sectionLabel("Smart Lists")
                        ForEach(matchedFilters, id: \.1) { entry in
                            row(icon: entry.2, color: entry.3, name: entry.1, meta: "") {
                                onSelectFilter(entry.0)
                            }
                        }
                    }
                    if !matchedLists.isEmpty {
                        sectionLabel("Lists")
                        ForEach(matchedLists, id: \.0.id) { entry in
                            row(icon: "list.bullet.rectangle", color: entry.1,
                                name: entry.0.title, meta: entry.0.isDefault ? "Default" : "") {
                                onSelectFilter(.list(entry.0.id))
                            }
                        }
                    }
                    if !matchedActions.isEmpty {
                        sectionLabel("Actions")
                        ForEach(matchedActions, id: \.1) { entry in
                            row(icon: entry.2, color: entry.3, name: entry.1, meta: "") {
                                onSelectAction(entry.0)
                            }
                        }
                    }
                    if matchedReminders.isEmpty && matchedFilters.isEmpty &&
                       matchedLists.isEmpty && matchedActions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.axisInkFaint)
                            Text("No matches")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.axisInkSoft)
                            Text("Try a different keyword.")
                                .font(.caption)
                                .foregroundStyle(Color.axisInkMute)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                }
                .padding(.vertical, AxisSpacing.sm)
            }
            .background(Color.axisCream)
        }
        .background(Color.axisCream.ignoresSafeArea())
        .onAppear { inputFocused = true }
    }

    private func reminderMeta(_ item: CalendarService.ReminderItem) -> String {
        var bits: [String] = []
        if let due = item.dueDate {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            bits.append(f.string(from: due))
        }
        if let list = item.calendarTitle { bits.append(list) }
        return bits.joined(separator: " · ")
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Color.axisInkMute)
            .padding(.horizontal, AxisSpacing.lg)
            .padding(.top, AxisSpacing.sm)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func row(icon: String, color: Color, name: String, meta: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ThingsIconCell(systemImage: icon, color: color, size: 26)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Color.axisInk)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(Color.axisInkMute)
                        .lineLimit(1)
                }
                Image(systemName: "return")
                    .font(.caption2)
                    .foregroundStyle(Color.axisInkFaint)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, AxisSpacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievements

/// A single collectible milestone. Unlock logic lives in AchievementsStore.
struct Achievement: Identifiable, Equatable {
    enum ID: String, CaseIterable { case streak7, streak30, streak365,
        centurion, halfThousand, perfectDay, perfectWeek }
    let id: ID
    let name: String
    let description: String
    let icon: String
    let gradientStart: Color
    let gradientEnd: Color
}

enum AchievementsStore {
    static let all: [Achievement] = [
        Achievement(id: .streak7, name: "7-Day Streak",
                    description: "One reminder done every day for a week.",
                    icon: "flame.fill",
                    gradientStart: Color(red: 1.0, green: 0.89, blue: 0.51),
                    gradientEnd: .axisYellowTone),
        Achievement(id: .centurion, name: "Centurion",
                    description: "100 reminders completed lifetime.",
                    icon: "100.circle.fill",
                    gradientStart: Color(red: 0.35, green: 0.66, blue: 1.0),
                    gradientEnd: .axisCobalt),
        Achievement(id: .perfectWeek, name: "Perfect Week",
                    description: "Every day this week had a completion.",
                    icon: "checkmark.seal.fill",
                    gradientStart: Color(red: 0.58, green: 0.90, blue: 0.67),
                    gradientEnd: .axisGreenTone),
        Achievement(id: .perfectDay, name: "Perfect Day",
                    description: "5+ reminders completed in one day.",
                    icon: "sparkles",
                    gradientStart: Color(red: 0.77, green: 0.71, blue: 0.99),
                    gradientEnd: .axisPurpleTone),
        Achievement(id: .streak30, name: "Monthly Strong",
                    description: "30 consecutive days with at least one completion.",
                    icon: "30.circle.fill",
                    gradientStart: Color(red: 1.0, green: 0.60, blue: 0.55),
                    gradientEnd: .axisRedTone),
        Achievement(id: .halfThousand, name: "Five Hundred",
                    description: "500 completions logged.",
                    icon: "500.circle.fill",
                    gradientStart: Color(red: 0.45, green: 0.78, blue: 0.74),
                    gradientEnd: .axisTealTone),
        Achievement(id: .streak365, name: "Year One",
                    description: "365 consecutive days — legendary.",
                    icon: "crown.fill",
                    gradientStart: Color(red: 1.0, green: 0.74, blue: 0.42),
                    gradientEnd: .axisOrangeTone)
    ]

    /// Returns the set of unlocked achievement IDs given the current stats.
    static func unlocked(streak: Int, total: Int, todayCount: Int,
                         bars: [CompletionTracker.DailyBar]) -> Set<Achievement.ID> {
        var unlocked: Set<Achievement.ID> = []
        if streak >= 7 { unlocked.insert(.streak7) }
        if streak >= 30 { unlocked.insert(.streak30) }
        if streak >= 365 { unlocked.insert(.streak365) }
        if total >= 100 { unlocked.insert(.centurion) }
        if total >= 500 { unlocked.insert(.halfThousand) }
        if todayCount >= 5 { unlocked.insert(.perfectDay) }
        if bars.count >= 7 && bars.suffix(7).allSatisfy({ $0.count > 0 }) {
            unlocked.insert(.perfectWeek)
        }
        return unlocked
    }
}

/// Single badge tile used in the achievements row of KarmaView.
struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: unlocked
                                ? [achievement.gradientStart, achievement.gradientEnd]
                                : [Color.axisInkFaint.opacity(0.4), Color.axisInkFaint.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 54, height: 54)
                        .shadow(color: (unlocked ? achievement.gradientEnd : Color.clear).opacity(0.30),
                                radius: 6, y: 3)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(unlocked ? .white : Color.axisInkMute)
                }
                Text(achievement.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(unlocked ? Color.axisInk : Color.axisInkMute)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            }
        }
        .buttonStyle(.plain)
        .opacity(unlocked ? 1.0 : 0.55)
        .sheet(isPresented: $showDetail) {
            VStack(spacing: AxisSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: unlocked
                                ? [achievement.gradientStart, achievement.gradientEnd]
                                : [Color.axisInkFaint.opacity(0.4), Color.axisInkFaint.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(unlocked ? .white : Color.axisInkMute)
                }
                .padding(.top, AxisSpacing.xl)

                Text(achievement.name)
                    .font(.title2.weight(.bold))
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(unlocked ? "Earned" : "Locked")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(unlocked ? Color.axisGreenSoft : Color.axisHairline))
                    .foregroundStyle(unlocked ? Color.axisGreenTone : Color.axisInkMute)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .presentationDetents([.medium])
        }
    }
}
