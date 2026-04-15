import ComposableArchitecture
import EventKit
import SwiftUI

struct EATaskListView: View {
    @Bindable var store: StoreOf<EATaskReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Natural language input
                taskInputBar

                // Filter segments — compact strip so the list dominates the viewport.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AxisSpacing.sm) {
                        ForEach(EATaskReducer.State.TaskFilter.allCases, id: \.self) { filter in
                            filterChip(filter)
                        }
                    }
                    .padding(.horizontal, AxisSpacing.lg)
                    .padding(.vertical, AxisSpacing.xs)
                }
                .scrollClipDisabled()

                // Task list
                if store.filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.isSelectMode ? "Done" : "Select") {
                        store.send(.toggleSelectMode)
                    }
                    .foregroundStyle(store.isSelectMode ? Color.axisAccent : .secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AxisSpacing.md) {
                        Menu {
                            ForEach(EATaskReducer.State.TaskSort.allCases, id: \.self) { sort in
                                Button {
                                    store.send(.sortChanged(sort))
                                } label: {
                                    HStack {
                                        Text(sort.rawValue)
                                        if store.sortMode == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(.secondary)
                        }

                        // Single gold action on this screen — adding a task.
                        Button {
                            store.send(.showAddTaskSheet)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisAccent)
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(item: Binding(
                get: { store.parsedPreview.map { IdentifiablePreview(preview: $0) } },
                set: { if $0 == nil { store.send(.cancelParsedTask) } }
            )) { _ in
                parsedPreviewSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showAddTask },
                set: { _ in store.send(.dismissAddTaskSheet) }
            )) {
                addTaskSheet
            }
            .sheet(item: selectedTaskBinding) { wrapper in
                taskDetailSheet(wrapper.task)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var selectedTaskBinding: Binding<IdentifiableTask?> {
        Binding(
            get: {
                guard let id = store.selectedTaskId,
                      let task = store.tasks.first(where: { $0.id == id }) else { return nil }
                return IdentifiableTask(task: task)
            },
            set: { if $0 == nil { store.send(.selectTask(nil)) } }
        )
    }

    // MARK: - Input Bar

    private var taskInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.axisGold)
                .font(.title3)

            TextField("Add a task...", text: $store.naturalLanguageInput.sending(\.naturalLanguageInputChanged))
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit { store.send(.submitNaturalLanguage) }

            if store.isAIParsing {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if !store.naturalLanguageInput.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    store.send(.submitNaturalLanguage)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.axisGold)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter Chips

    private func filterChip(_ filter: EATaskReducer.State.TaskFilter) -> some View {
        let isSelected = store.selectedFilter == filter
        let count: Int
        switch filter {
        case .all: count = store.tasks.filter { $0.status != "cancelled" }.count
        case .inbox: count = store.tasks.filter { $0.status == "inbox" }.count
        case .scheduled: count = store.tasks.filter { $0.status == "scheduled" }.count
        case .inProgress: count = store.tasks.filter { $0.status == "inProgress" }.count
        case .done: count = store.tasks.filter { $0.status == "completed" }.count
        }

        return Button { store.send(.filterChanged(filter)) } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.axisGold : Color.secondary.opacity(0.3))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.axisGold.opacity(0.15) : .clear)
            .foregroundStyle(isSelected ? Color.axisGold : .secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.axisGold : Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.filteredTasks) { task in
                    HStack(spacing: 12) {
                        if store.isSelectMode {
                            Image(systemName: store.selectedTaskIds.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(store.selectedTaskIds.contains(task.id) ? Color.axisGold : .secondary)
                                .onTapGesture { store.send(.toggleTaskSelection(task.id)) }
                        }
                        taskRow(task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { store.send(.deleteTask(task.id)) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if task.status == "completed" {
                                store.send(.updateTaskStatus(task.id, "inbox"))
                            } else {
                                store.send(.completeTask(task.id))
                            }
                        } label: {
                            Label(
                                task.status == "completed" ? "Reopen" : "Done",
                                systemImage: task.status == "completed" ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                        .tint(.green)
                    }
                }
            }
            .listStyle(.plain)

            if store.isSelectMode {
                batchActionBar
            }
        }
    }

    private var batchActionBar: some View {
        HStack {
            Button { store.send(.selectAll) } label: {
                Text("All").font(.caption)
            }
            Spacer()
            Text("\(store.selectedTaskIds.count) selected")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { store.send(.batchComplete) } label: {
                Label("Complete", systemImage: "checkmark.circle")
                    .font(.caption)
            }
            .tint(.green)
            Button(role: .destructive) { store.send(.batchDelete) } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
        }
        .padding()
        .background(.bar)
    }

    private func taskRow(_ task: EATaskReducer.State.TaskState) -> some View {
        Button { store.send(.selectTask(task.id)) } label: {
            HStack(spacing: 12) {
                // Priority indicator
                Circle()
                    .fill(priorityColor(task.priority))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .strikethrough(task.status == "completed")
                            .foregroundStyle(task.status == "completed" ? .secondary : .primary)

                        if task.isAtRisk {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 8) {
                        if let mins = task.estimatedMinutes {
                            Label("\(mins)m", systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(task.category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                        if let deadline = task.deadline {
                            Text(deadline, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(task.isAtRisk ? .red : .secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Edit
            Button {
                store.send(.showAddTaskSheet)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            // Mark Complete / Reopen
            Button {
                if task.status == "completed" {
                    store.send(.updateTaskStatus(task.id, "inbox"))
                } else {
                    store.send(.completeTask(task.id))
                }
            } label: {
                Label(
                    task.status == "completed" ? "Reopen" : "Mark Complete",
                    systemImage: "checkmark.circle"
                )
            }

            // Change Priority submenu
            Menu {
                Button {
                    store.send(.updateTaskPriority(task.id, "critical"))
                } label: {
                    Label("Critical", systemImage: task.priority == "critical" ? "checkmark" : "circle.fill")
                        .foregroundStyle(.red)
                }
                Button {
                    store.send(.updateTaskPriority(task.id, "high"))
                } label: {
                    Label("High", systemImage: task.priority == "high" ? "checkmark" : "circle.fill")
                        .foregroundStyle(.orange)
                }
                Button {
                    store.send(.updateTaskPriority(task.id, "medium"))
                } label: {
                    Label("Medium", systemImage: task.priority == "medium" ? "checkmark" : "circle.fill")
                        .foregroundStyle(.yellow)
                }
                Button {
                    store.send(.updateTaskPriority(task.id, "low"))
                } label: {
                    Label("Low", systemImage: task.priority == "low" ? "checkmark" : "circle.fill")
                        .foregroundStyle(.green)
                }
            } label: {
                Label("Change Priority", systemImage: "flag")
            }

            Divider()

            // Text Details (Messages)
            Button {
                let text = taskPlainText(task)
                if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "sms:&body=\(encoded)") {
                    PlatformServices.openURL(url)
                }
            } label: {
                Label("Text Details", systemImage: "message")
            }

            // Copy Details
            Button {
                PlatformServices.copyToClipboard(taskPlainText(task))
            } label: {
                Label("Copy Details", systemImage: "doc.on.doc")
            }

            // Add to Calendar
            Button {
                addTaskToCalendar(task)
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }

            Divider()

            // Delete
            Button(role: .destructive) {
                store.send(.deleteTask(task.id))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tasks here")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try adding one using natural language above")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Parsed Preview Sheet

    private var parsedPreviewSheet: some View {
        NavigationStack {
            if let preview = store.parsedPreview {
                Form {
                    Section("AI Parsed Task") {
                        LabeledContent("Title", value: preview.title)
                        LabeledContent("Priority", value: preview.priority.capitalized)
                        LabeledContent("Category", value: preview.category.capitalized)
                        LabeledContent("Energy", value: preview.energyLevel == "deepWork" ? "Deep Work" : "Light Work")
                        if let mins = preview.estimatedMinutes {
                            LabeledContent("Duration", value: "\(mins) min")
                        }
                        if let deadline = preview.deadline {
                            LabeledContent("Deadline") {
                                Text(deadline, style: .date)
                            }
                        }
                    }
                }
                .navigationTitle("Confirm Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { store.send(.cancelParsedTask) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { store.send(.confirmParsedTask) }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Task Sheet

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $store.newTaskTitle.sending(\.newTaskTitleChanged))
                }
                Section("Priority") {
                    Picker("Priority", selection: $store.newTaskPriority.sending(\.newTaskPriorityChanged)) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                        Text("Critical").tag("critical")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Category") {
                    Picker("Category", selection: $store.newTaskCategory.sending(\.newTaskCategoryChanged)) {
                        Text("Personal").tag("personal")
                        Text("University").tag("university")
                        Text("Consulting").tag("consulting")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Duration (minutes)") {
                    Picker("Duration", selection: $store.newTaskDuration.sending(\.newTaskDurationChanged)) {
                        Text("15").tag(15)
                        Text("25").tag(25)
                        Text("30").tag(30)
                        Text("45").tag(45)
                        Text("60").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddTaskSheet) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { store.send(.confirmNewTask) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.axisGold)
                        .disabled(store.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func taskDetailSheet(_ task: EATaskReducer.State.TaskState) -> some View {
        NavigationStack {
            List {
                Section("Task") {
                    LabeledContent("Title", value: task.title)
                    LabeledContent("Status", value: task.status)
                    LabeledContent("Priority", value: task.priority.capitalized)
                    LabeledContent("Category", value: task.category.capitalized)
                    if let mins = task.estimatedMinutes {
                        LabeledContent("Duration", value: "\(mins) min")
                    }
                    if let deadline = task.deadline {
                        LabeledContent("Deadline") {
                            Text(deadline, style: .date)
                        }
                    }
                }
                Section("Actions") {
                    Button("Mark Complete") {
                        store.send(.completeTask(task.id))
                        store.send(.selectTask(nil))
                    }
                    Button("Move to In Progress") {
                        store.send(.updateTaskStatus(task.id, "inProgress"))
                        store.send(.selectTask(nil))
                    }
                    Button("Move to Inbox") {
                        store.send(.updateTaskStatus(task.id, "inbox"))
                        store.send(.selectTask(nil))
                    }
                    Button(role: .destructive) {
                        store.send(.deleteTask(task.id))
                        store.send(.selectTask(nil))
                    } label: {
                        Text("Delete Task")
                    }
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.selectTask(nil)) }
                }
            }
        }
    }

    // MARK: - Context Menu Helpers

    private func taskPlainText(_ task: EATaskReducer.State.TaskState) -> String {
        var lines: [String] = [task.title]

        var details: [String] = []
        details.append("Priority: \(task.priority.capitalized)")
        if let deadline = task.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            details.append("Due: \(formatter.string(from: deadline))")
        }
        lines.append(details.joined(separator: " | "))

        lines.append("Category: \(task.category.capitalized)")

        return lines.joined(separator: "\n")
    }

    private func addTaskToCalendar(_ task: EATaskReducer.State.TaskState) {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else { return }
            let event = EKEvent(eventStore: eventStore)
            event.title = task.title
            event.notes = "Priority: \(task.priority.capitalized)\nCategory: \(task.category.capitalized)"
            if let deadline = task.deadline {
                event.startDate = deadline
                event.endDate = Calendar.current.date(byAdding: .minute, value: task.estimatedMinutes ?? 30, to: deadline) ?? deadline.addingTimeInterval(1800)
            } else {
                let start = Date()
                event.startDate = start
                event.endDate = Calendar.current.date(byAdding: .minute, value: task.estimatedMinutes ?? 30, to: start) ?? start.addingTimeInterval(1800)
            }
            event.calendar = eventStore.defaultCalendarForNewEvents
            do {
                try eventStore.save(event, span: .thisEvent)
            } catch {
                // Calendar save failed silently
            }
        }
    }

    // MARK: - Helpers

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "critical": return .red
        case "high": return .orange
        case "medium": return Color.axisGold
        case "low": return .green
        default: return .gray
        }
    }
}

// Helper for sheet binding
private struct IdentifiablePreview: Identifiable {
    let id = UUID()
    let preview: EATaskReducer.State.ParsedPreviewState
}

private struct IdentifiableTask: Identifiable {
    let id: UUID
    let task: EATaskReducer.State.TaskState

    init(task: EATaskReducer.State.TaskState) {
        self.id = task.id
        self.task = task
    }
}

#Preview {
    EATaskListView(
        store: Store(initialState: EATaskReducer.State()) {
            EATaskReducer()
        }
    )
}
