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

    @State private var vm = RemindersViewModel()
    @State private var showAddSheet = false
    @State private var selectedReminder: CalendarService.ReminderItem?
    @State private var newQuickTitle = ""
    @FocusState private var quickFocused: Bool

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
            // Quick add row always at the top
            Section {
                HStack(spacing: AxisSpacing.sm) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.axisAccent)
                    TextField("Add a reminder", text: $newQuickTitle)
                        .focused($quickFocused)
                        .submitLabel(.done)
                        .onSubmit { submitQuickAdd() }
                    if !newQuickTitle.isEmpty {
                        Button("Add") { submitQuickAdd() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.axisAccent)
                    }
                }
            }

            section(title: "Overdue", items: vm.overdue, accent: Color.axisDanger)
            section(title: "Today", items: vm.today, accent: Color.axisAccent)
            section(title: "Upcoming", items: vm.upcoming, accent: Color.axisInfo)
            section(title: "No Date", items: vm.undated, accent: Color.secondary)

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
                        ReminderRow(item: item, accent: accent, onToggle: { await vm.toggleComplete(item) })
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

    private func submitQuickAdd() {
        let trimmed = newQuickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            _ = CalendarService.shared.createReminder(title: trimmed)
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
    var state: LoadState = .loading
    var overdue: [CalendarService.ReminderItem] = []
    var today: [CalendarService.ReminderItem] = []
    var upcoming: [CalendarService.ReminderItem] = []
    var undated: [CalendarService.ReminderItem] = []
    var byId: [String: CalendarService.ReminderItem] = [:]

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
    }

    func toggleComplete(_ item: CalendarService.ReminderItem) async {
        _ = item.isCompleted
            ? CalendarService.shared.uncompleteReminder(id: item.id)
            : CalendarService.shared.completeReminder(id: item.id)
        await reload()
    }

    func delete(_ item: CalendarService.ReminderItem) async {
        _ = CalendarService.shared.deleteReminder(id: item.id)
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
                }

                Section("Due") {
                    Toggle("Has due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: includesTime ? [.date, .hourAndMinute] : .date)
                        Toggle("Include time", isOn: $includesTime)
                    }
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
        switch mode {
        case .create:
            title = ""
            hasDueDate = false
            includesTime = false
            priority = 0
            notes = ""
            meetingInfo = ""
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
            addToCalendar = false
            eventStart = item.dueDate ?? Date()
            eventEnd = (item.dueDate ?? Date()).addingTimeInterval(3600)
            eventLocation = ""
        }
    }

    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let id: String?
        switch mode {
        case .create:
            id = CalendarService.shared.createReminder(
                title: cleaned,
                notes: notes.isEmpty ? nil : notes,
                meetingInfo: meetingInfo.isEmpty ? nil : meetingInfo,
                dueDate: hasDueDate ? dueDate : nil,
                includeDueTime: includesTime,
                priority: priority
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
                priority: priority
            )
            id = ok ? item.id : nil
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
