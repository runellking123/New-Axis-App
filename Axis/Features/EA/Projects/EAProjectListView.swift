import ComposableArchitecture
import SwiftUI

struct EAProjectListView: View {
    @Bindable var store: StoreOf<EAProjectReducer>

    var body: some View {
        NavigationStack {
            mainProjectContent
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Projects")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { addProjectButton }
                .sheet(item: scaffoldBinding) { _ in scaffoldPreviewSheet }
                .sheet(item: projectDetailBinding) { wrapper in projectDetailSheet(wrapper.project) }
                .sheet(isPresented: Binding(
                    get: { store.showCreateProject },
                    set: { _ in store.send(.dismissCreateProjectSheet) }
                )) {
                    createProjectSheet
                }
                .onAppear { store.send(.onAppear) }
        }
    }

    private var mainProjectContent: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $store.selectedView.sending(\.viewChanged)) {
                ForEach(EAProjectReducer.State.ProjectView.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch store.selectedView {
            case .list:
                projectListView
            case .kanban:
                kanbanView
            }
        }
    }

    private var addProjectButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.showCreateProjectSheet)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.axisGold)
            }
        }
    }

    private var scaffoldBinding: Binding<IdentifiableScaffold?> {
        Binding(
            get: { store.scaffoldedPreview.map { IdentifiableScaffold(preview: $0) } },
            set: { if $0 == nil { store.send(.cancelScaffold) } }
        )
    }

    private var projectDetailBinding: Binding<IdentifiableProject?> {
        Binding(
            get: {
                guard let id = store.selectedProjectId,
                      let project = store.projects.first(where: { $0.id == id }) else { return nil }
                return IdentifiableProject(project: project)
            },
            set: { if $0 == nil { store.send(.selectProject(nil)) } }
        )
    }

    // MARK: - AI Input

    private var aiInputSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.axisGold)
            TextField("Describe a project...", text: $store.naturalLanguageInput.sending(\.naturalLanguageInputChanged))
                .submitLabel(.done)
                .onSubmit { store.send(.scaffoldWithAI) }
            if store.isScaffolding {
                ProgressView()
                    .scaleEffect(0.8)
            }
            if !store.naturalLanguageInput.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    store.send(.scaffoldWithAI)
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

    // MARK: - List View

    private var projectListView: some View {
        VStack(spacing: 0) {
            aiInputSection

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton("All", value: "all", current: store.filterStatus) {
                        store.send(.filterStatusChanged($0))
                    }
                    filterButton("Active", value: "active", current: store.filterStatus) {
                        store.send(.filterStatusChanged($0))
                    }
                    filterButton("On Hold", value: "onHold", current: store.filterStatus) {
                        store.send(.filterStatusChanged($0))
                    }
                    filterButton("Completed", value: "completed", current: store.filterStatus) {
                        store.send(.filterStatusChanged($0))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if store.filteredProjects.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No projects yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Describe a project above or tap + to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.filteredProjects) { project in
                        Button { store.send(.selectProject(project.id)) } label: {
                            projectRow(project)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.send(.deleteProject(project.id))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                let newStatus = project.status == "active" ? "completed" : "active"
                                store.send(.updateProjectStatus(project.id, newStatus))
                            } label: {
                                Label(
                                    project.status == "active" ? "Complete" : "Activate",
                                    systemImage: project.status == "active" ? "checkmark.circle" : "play.circle"
                                )
                            }
                            .tint(project.status == "active" ? .green : .blue)
                        }
                        .contextMenu {
                            Button {
                                let newStatus = project.status == "active" ? "completed" : "active"
                                store.send(.updateProjectStatus(project.id, newStatus))
                            } label: {
                                Label(project.status == "active" ? "Mark Completed" : "Mark Active", systemImage: "checkmark.circle")
                            }
                            Button {
                                store.send(.selectProject(project.id))
                            } label: {
                                Label("Open Details", systemImage: "info.circle")
                            }
                            Button(role: .destructive) {
                                store.send(.deleteProject(project.id))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func projectRow(_ project: EAProjectReducer.State.ProjectState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(project.status.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(project.status).opacity(0.15))
                    .foregroundStyle(statusColor(project.status))
                    .clipShape(Capsule())
            }

            ProgressView(value: project.progress)
                .tint(Color.axisGold)

            HStack {
                Text("\(project.completedTaskCount)/\(project.tasks.count) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let deadline = project.deadline {
                    Text(deadline, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let note = project.statusNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 6))
            }

            if project.hasAtRiskDependencies {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("Has at-risk tasks")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Project Detail Sheet

    private func projectDetailSheet(_ project: EAProjectReducer.State.ProjectState) -> some View {
        ProjectWorkspaceView(store: store, project: project, priorityColor: priorityColor)
    }

    // MARK: - Kanban View

    private var kanbanView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                kanbanColumn("Backlog", tasks: store.backlogTasks, color: .gray)
                kanbanColumn("In Progress", tasks: store.inProgressTasks, color: .blue)
                kanbanColumn("Review", tasks: store.reviewTasks, color: .orange)
                kanbanColumn("Done", tasks: store.doneTasks, color: .green)
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    private func kanbanColumn(_ title: String, tasks: [EAProjectReducer.State.TaskState], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text("\(tasks.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(color)
            }

            ForEach(tasks) { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    HStack {
                        Circle()
                            .fill(priorityColor(task.priority))
                            .frame(width: 6, height: 6)
                        if let mins = task.estimatedMinutes {
                            Text("\(mins)m")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .frame(width: 160)
    }

    // MARK: - Scaffold Preview

    private var scaffoldPreviewSheet: some View {
        NavigationStack {
            if let preview = store.scaffoldedPreview {
                List {
                    Section("Project") {
                        LabeledContent("Title", value: preview.title)
                        LabeledContent("Category", value: preview.category.capitalized)
                        if let days = preview.estimatedDays {
                            LabeledContent("Estimated", value: "\(days) days")
                        }
                    }

                    Section("Subtasks (\(preview.subtasks.count))") {
                        ForEach(preview.subtasks) { task in
                            HStack {
                                Circle()
                                    .fill(priorityColor(task.priority))
                                    .frame(width: 8, height: 8)
                                Text(task.title)
                                    .font(.subheadline)
                                Spacer()
                                if let mins = task.estimatedMinutes {
                                    Text("\(mins)m")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("Milestones") {
                        ForEach(preview.milestones) { ms in
                            HStack {
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.axisGold)
                                Text(ms.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("Day \(ms.relativeDayOffset)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("AI Project Plan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { store.send(.cancelScaffold) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { store.send(.confirmScaffold) }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
        }
    }

    // MARK: - Create Project Sheet

    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section("Project Name") {
                    TextField("Enter project name", text: $store.newProjectTitle.sending(\.newProjectTitleChanged))
                }
                Section("Template") {
                    Picker("Template", selection: $store.newProjectTemplate.sending(\.newProjectTemplateChanged)) {
                        Text("Blank").tag("")
                        Text("Accreditation Report").tag("accreditation")
                        Text("IPEDS Submission").tag("ipeds")
                        Text("Grant Proposal").tag("grant")
                        Text("Data Analysis").tag("analysis")
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $store.newProjectCategory.sending(\.newProjectCategoryChanged)) {
                        Text("Personal").tag("personal")
                        Text("University").tag("university")
                        Text("Consulting").tag("consulting")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Description (optional)") {
                    TextField("Describe the project...", text: $store.newProjectDescription.sending(\.newProjectDescriptionChanged), axis: .vertical)
                        .lineLimit(3...6)
                }
                if !store.newProjectTemplate.isEmpty {
                    Section("Template Preview") {
                        let data = EAProjectReducer.templateData(for: store.newProjectTemplate)
                        ForEach(Array(data.tasks.enumerated()), id: \.offset) { _, task in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(priorityColor(task.priority))
                                    .frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.caption)
                                Spacer()
                                if let mins = task.estimatedMinutes {
                                    Text("\(mins)m")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        ForEach(Array(data.milestones.enumerated()), id: \.offset) { _, ms in
                            HStack(spacing: 8) {
                                Image(systemName: "flag.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.axisGold)
                                Text(ms.title)
                                    .font(.caption)
                                Spacer()
                                Text("Day \(ms.relativeDayOffset)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissCreateProjectSheet) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { store.send(.confirmCreateProject) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.axisGold)
                        .disabled(store.newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Helpers

    private func filterButton(_ label: String, value: String, current: String, action: @escaping (String) -> Void) -> some View {
        let isSelected = current == value
        return Button { action(value) } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.axisGold.opacity(0.15) : .clear)
                .foregroundStyle(isSelected ? Color.axisGold : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.axisGold : Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return .green
        case "onHold": return .orange
        case "completed": return .blue
        case "archived": return .gray
        default: return .secondary
        }
    }

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

private struct ProjectWorkspaceView: View {
    let store: StoreOf<EAProjectReducer>
    let project: EAProjectReducer.State.ProjectState
    let priorityColor: (String) -> Color
    @State private var showAddTask = false
    @State private var showAddMilestone = false
    @State private var newTaskTitle = ""
    @State private var newTaskPriority = "medium"
    @State private var newTaskMinutes = 30
    @State private var newMilestoneTitle = ""
    @State private var newMilestoneDate = Date()
    @State private var statusNoteText: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    LabeledContent("Status", value: project.status.capitalized)
                    LabeledContent("Category", value: project.category.capitalized)
                    LabeledContent("Progress", value: "\(Int(project.progress * 100))%")
                    if let description = project.projectDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                    }
                    if let deadline = project.deadline {
                        LabeledContent("Deadline") { Text(deadline, style: .date) }
                    }
                }

                Section("Status Update") {
                    TextField("Status update...", text: $statusNoteText)
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                        .onAppear { statusNoteText = project.statusNote ?? "" }
                        .onSubmit {
                            store.send(.updateStatusNote(project.id, statusNoteText))
                        }
                        .onChange(of: statusNoteText) { _, newValue in
                            store.send(.updateStatusNote(project.id, newValue))
                        }
                }

                Section("Actions") {
                    Button("Add Project Task") { showAddTask = true }
                    Button("Add Milestone") { showAddMilestone = true }
                    Button(project.status == "active" ? "Mark Project Completed" : "Mark Project Active") {
                        store.send(.updateProjectStatus(project.id, project.status == "active" ? "completed" : "active"))
                    }
                }

                Section("Tasks (\(project.completedTaskCount)/\(project.tasks.count))") {
                    if project.tasks.isEmpty {
                        Text("No project tasks yet. Add the next concrete step.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(project.tasks) { task in
                            Button {
                                store.send(.toggleProjectTaskStatus(projectId: project.id, taskId: task.id))
                            } label: {
                                HStack {
                                    Image(systemName: task.status == "completed" ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.status == "completed" ? .green : priorityColor(task.priority))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .strikethrough(task.status == "completed")
                                            .foregroundStyle(.primary)
                                        Text(task.status.replacingOccurrences(of: "inProgress", with: "in progress").capitalized)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let mins = task.estimatedMinutes {
                                        Text("\(mins)m")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Milestone Timeline") {
                    if project.milestones.isEmpty {
                        Text("No milestones yet. Add checkpoints for this project.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(project.milestones.sorted { $0.sortOrder < $1.sortOrder }.enumerated()), id: \.element.id) { index, milestone in
                            Button {
                                store.send(.toggleMilestoneCompletion(projectId: project.id, milestoneId: milestone.id))
                            } label: {
                                HStack(spacing: 12) {
                                    // Timeline visual
                                    VStack(spacing: 0) {
                                        if index > 0 {
                                            Rectangle()
                                                .fill(milestone.isCompleted ? Color.green.opacity(0.5) : Color.secondary.opacity(0.2))
                                                .frame(width: 2, height: 12)
                                        } else {
                                            Spacer().frame(height: 12)
                                        }
                                        Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(milestone.isCompleted ? .green : Color.axisGold)
                                        if index < project.milestones.count - 1 {
                                            Rectangle()
                                                .fill(milestone.isCompleted ? Color.green.opacity(0.5) : Color.secondary.opacity(0.2))
                                                .frame(width: 2, height: 12)
                                        } else {
                                            Spacer().frame(height: 12)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(milestone.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .strikethrough(milestone.isCompleted)
                                            .foregroundStyle(.primary)
                                        if let dueDate = milestone.dueDate {
                                            let isPast = dueDate < Date() && !milestone.isCompleted
                                            Text(dueDate, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(isPast ? .red : .secondary)
                                        }
                                    }

                                    Spacer()

                                    if milestone.isCompleted {
                                        Text("Done")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    } else if let dueDate = milestone.dueDate {
                                        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                                        if daysUntil < 0 {
                                            Text("Overdue")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        } else if daysUntil == 0 {
                                            Text("Today")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        } else {
                                            Text("\(daysUntil)d")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.send(.deleteProject(project.id))
                        store.send(.selectProject(nil))
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.send(.selectProject(nil)) }
                }
            }
            .sheet(isPresented: $showAddTask) {
                NavigationStack {
                    Form {
                        Section("Task") {
                            TextField("Task title", text: $newTaskTitle)
                            Picker("Priority", selection: $newTaskPriority) {
                                Text("Low").tag("low")
                                Text("Medium").tag("medium")
                                Text("High").tag("high")
                                Text("Critical").tag("critical")
                            }
                            Picker("Duration", selection: $newTaskMinutes) {
                                Text("15").tag(15)
                                Text("30").tag(30)
                                Text("45").tag(45)
                                Text("60").tag(60)
                            }
                        }
                    }
                    .navigationTitle("Add Task")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddTask = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                store.send(.addTaskToProject(projectId: project.id, title: newTaskTitle, priority: newTaskPriority, estimatedMinutes: newTaskMinutes))
                                showAddTask = false
                                store.send(.onAppear)
                            }
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddMilestone) {
                NavigationStack {
                    Form {
                        Section("Milestone") {
                            TextField("Milestone title", text: $newMilestoneTitle)
                            DatePicker("Due Date", selection: $newMilestoneDate, displayedComponents: .date)
                        }
                    }
                    .navigationTitle("Add Milestone")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddMilestone = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                store.send(.addMilestoneToProject(projectId: project.id, title: newMilestoneTitle, dueDate: newMilestoneDate))
                                showAddMilestone = false
                                store.send(.onAppear)
                            }
                            .disabled(newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }
}

private struct IdentifiableScaffold: Identifiable {
    let id = UUID()
    let preview: EAProjectReducer.State.ScaffoldedPreviewState
}

private struct IdentifiableProject: Identifiable {
    let id: UUID
    let project: EAProjectReducer.State.ProjectState

    init(project: EAProjectReducer.State.ProjectState) {
        self.id = project.id
        self.project = project
    }
}
