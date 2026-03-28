import ComposableArchitecture
import SwiftUI

struct EATaskListView: View {
    @Bindable var store: StoreOf<EATaskReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Natural language input
                taskInputBar

                // Filter segments
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EATaskReducer.State.TaskFilter.allCases, id: \.self) { filter in
                            filterChip(filter)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Task list
                if store.filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.isSelectMode ? "Done" : "Select") {
                        store.send(.toggleSelectMode)
                    }
                    .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
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
                                .foregroundStyle(Color.axisGold)
                        }

                        Button {
                            store.send(.showAddTaskSheet)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisGold)
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
                        Button { store.send(.completeTask(task.id)) } label: {
                            Label("Done", systemImage: "checkmark")
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
            Button {
                store.send(.completeTask(task.id))
            } label: {
                Label("Mark Complete", systemImage: "checkmark.circle")
            }
            Button {
                store.send(.updateTaskStatus(task.id, "inProgress"))
            } label: {
                Label("Move to In Progress", systemImage: "play.circle")
            }
            Button {
                store.send(.updateTaskStatus(task.id, "inbox"))
            } label: {
                Label("Move to Inbox", systemImage: "tray")
            }
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
