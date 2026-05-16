import ComposableArchitecture
import EventKit
import SwiftUI

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

    @State private var vm = RemindersViewModel()
    @State private var showAddSheet = false
    @State private var selectedReminder: CalendarService.ReminderItem?
    @State private var newQuickTitle = ""
    @FocusState private var quickFocused: Bool
    @AppStorage("workflow.grouping") private var grouping: Grouping = .date

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
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.secondary)
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
            .task { await vm.requestAccessAndLoad() }
            .refreshable { await vm.reload() }
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
            }

            switch grouping {
            case .date:
                section(title: "Overdue", items: vm.overdue, accent: Color.axisDanger)
                section(title: "Today", items: vm.today, accent: Color.axisAccent)
                section(title: "Upcoming", items: vm.upcoming, accent: Color.axisInfo)
                section(title: "No Date", items: vm.undated, accent: Color.secondary)
            case .list:
                ForEach(itemsGroupedByList(), id: \.title) { group in
                    section(title: group.title, items: group.items, accent: Color.axisAccent)
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
                        ReminderRow(item: item, accent: accent, subtaskProgress: vm.subtaskProgress[item.id], onToggle: { await vm.toggleComplete(item) })
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
                    }
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
    let onToggle: () async -> Void

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
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                    .lineLimit(2)
                HStack(spacing: AxisSpacing.sm) {
                    if let due = item.dueDate {
                        Label {
                            Text(formattedDue(due, includesTime: item.hasDueTime))
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        Label {
                            Text("\(progress.done)/\(progress.total)")
                        } icon: {
                            Image(systemName: progress.done == progress.total ? "checklist.checked" : "checklist")
                        }
                        .font(.caption)
                        .foregroundStyle(progress.done == progress.total ? accent : .secondary)
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
    var state: LoadState = .loading
    var overdue: [CalendarService.ReminderItem] = []
    var today: [CalendarService.ReminderItem] = []
    var upcoming: [CalendarService.ReminderItem] = []
    var undated: [CalendarService.ReminderItem] = []
    var byId: [String: CalendarService.ReminderItem] = [:]
    var subtaskProgress: [String: SubtaskProgress] = [:]

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
        overdueBucket.sort { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        todayBucket.sort { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        upcomingBucket.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        overdue = overdueBucket
        today = todayBucket
        upcoming = upcomingBucket
        undated = undatedBucket
        byId = map

        let grouped = PersistenceService.shared.fetchAllReminderSubtasks()
        subtaskProgress = grouped.mapValues { rows in
            SubtaskProgress(done: rows.filter(\.isCompleted).count, total: rows.count)
        }
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
