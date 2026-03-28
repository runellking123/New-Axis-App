import ComposableArchitecture
import SwiftUI

struct WorkSuiteView: View {
    @Bindable var store: StoreOf<WorkSuiteReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Workspace picker
                workspacePicker

                // Segment control
                segmentPicker

                ScrollView {
                    VStack(spacing: 16) {
                        switch store.selectedSegment {
                        case .projects:
                            projectsSection
                        case .focus:
                            focusSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Work Suite")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.selectedSegment == .projects {
                        Button {
                            store.send(.toggleAddProject)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisGold)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddProject },
                set: { newValue in
                    if !newValue { store.send(.dismissAddProject) }
                }
            )) {
                addProjectSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showAmbientMixer },
                set: { newValue in
                    if !newValue { store.send(.dismissAmbientMixer) }
                }
            )) {
                AmbientSoundMixerView(store: store)
            }
            .navigationDestination(isPresented: Binding(
                get: { store.selectedProjectId != nil },
                set: { if !$0 { store.send(.selectProject(nil)) } }
            )) {
                if let id = store.selectedProjectId, let project = store.projects.first(where: { $0.id == id }) {
                    ProjectDetailView(store: store, project: project)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Workspace Picker

    private var workspacePicker: some View {
        HStack(spacing: 0) {
            ForEach(WorkSuiteReducer.State.Workspace.allCases, id: \.self) { workspace in
                Button {
                    store.send(.workspaceChanged(workspace))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: workspace.icon)
                            .font(.caption)
                        Text(workspace.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        store.selectedWorkspace == workspace
                            ? Color.axisGold.opacity(0.15)
                            : Color.clear
                    )
                    .foregroundStyle(
                        store.selectedWorkspace == workspace
                            ? Color.axisGold
                            : .secondary
                    )
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        Picker("Section", selection: $store.selectedSegment.sending(\.segmentChanged)) {
            ForEach(WorkSuiteReducer.State.Segment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 12) {
            WidgetCardView(
                icon: "folder.fill",
                title: "Active",
                value: "\(store.activeProjectCount)",
                subtitle: "projects",
                color: Color.axisGold
            )
            WidgetCardView(
                icon: "checkmark.circle.fill",
                title: "Done",
                value: "\(store.completedProjectCount)",
                subtitle: "completed",
                color: .green
            )
        }
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(spacing: 12) {
            statsBar

            Picker("Sort Projects", selection: $store.projectSort.sending(\.projectSortChanged)) {
                ForEach(WorkSuiteReducer.State.ProjectSort.allCases, id: \.self) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.segmented)

            // Active projects
            let active = store.sortedFilteredProjects.filter { $0.status == "active" }
            if !active.isEmpty {
                sectionHeader("Active", count: active.count)
                ForEach(active) { project in
                    Button {
                        store.send(.selectProject(project.id))
                    } label: {
                        projectCard(project)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Completed projects
            let completed = store.sortedFilteredProjects.filter { $0.status == "completed" }
            if !completed.isEmpty {
                sectionHeader("Completed", count: completed.count)
                ForEach(completed) { project in
                    Button {
                        store.send(.selectProject(project.id))
                    } label: {
                        projectCard(project)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.filteredProjects.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("No projects in this workspace yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .padding(.top, 4)
    }

    private func projectCard(_ project: WorkSuiteReducer.State.ProjectState) -> some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        store.send(.toggleProjectStatus(project.id))
                    } label: {
                        Image(systemName: project.status == "completed" ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(project.status == "completed" ? .green : .secondary)
                    }

                    // Priority indicator
                    Circle()
                        .fill(priorityColor(project.priority))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .strikethrough(project.status == "completed")
                            .foregroundStyle(project.status == "completed" ? .secondary : .primary)
                        HStack(spacing: 6) {
                            Text(project.priority.capitalized + " Priority")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let dueDate = project.dueDate {
                                Text("Due \(dueDate.shortDateString)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(dueDate < Date() ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                                    .foregroundStyle(dueDate < Date() ? .red : .blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Button {
                        store.send(.deleteProject(project.id))
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Subtask progress bar
                if !project.subtasks.isEmpty {
                    VStack(spacing: 4) {
                        ProgressView(value: project.subtaskProgress)
                            .tint(project.subtaskProgress >= 1.0 ? .green : Color.axisGold)
                        HStack {
                            Text("\(project.completedSubtaskCount)/\(project.subtasks.count) subtasks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if project.estimatedPomodoros > 0 {
                                let completed = store.projectTimeSummary[project.id] ?? 0
                                Text("\(completed / (store.focusSessionMinutes > 0 ? store.focusSessionMinutes : 25))/\(project.estimatedPomodoros) pomodoros")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 44)
                }
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(spacing: 16) {
            // Time summary card
            GlassCard {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(store.totalFocusMinutesToday)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.axisGold)
                        Text("min today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("\(store.totalFocusMinutesThisWeek)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.axisGold)
                        Text("min this week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text("\(store.completedPomodorosInCycle)/\(store.pomodorosBeforeLongBreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.axisGold)
                        Text("cycle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Project selector for focus
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus on Project")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                store.send(.setActiveProjectForFocus(nil))
                            } label: {
                                Text("None")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(store.activeProjectForFocus == nil ? Color.axisGold.opacity(0.2) : Color(.systemGray5))
                                    .foregroundStyle(store.activeProjectForFocus == nil ? Color.axisGold : .secondary)
                                    .clipShape(Capsule())
                            }
                            ForEach(store.projects.filter { $0.status == "active" }) { project in
                                Button {
                                    store.send(.setActiveProjectForFocus(project.id))
                                } label: {
                                    Text(project.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(store.activeProjectForFocus == project.id ? Color.axisGold.opacity(0.2) : Color(.systemGray5))
                                        .foregroundStyle(store.activeProjectForFocus == project.id ? Color.axisGold : .secondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }

            // Timer display
            GlassCard {
                VStack(spacing: 20) {
                    // Phase indicator
                    HStack(spacing: 8) {
                        ForEach(WorkSuiteReducer.State.PomodoroPhase.allCases, id: \.self) { phase in
                            Text(phase.rawValue)
                                .font(.caption)
                                .fontWeight(store.pomodoroPhase == phase ? .bold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(store.pomodoroPhase == phase ? phaseColor(phase).opacity(0.15) : Color.clear)
                                .foregroundStyle(store.pomodoroPhase == phase ? phaseColor(phase) : .secondary)
                                .clipShape(Capsule())
                        }
                    }

                    ZStack {
                        Circle()
                            .stroke(phaseColor(store.pomodoroPhase).opacity(0.2), lineWidth: 8)
                            .frame(width: 180, height: 180)

                        Circle()
                            .trim(from: 0, to: (store.focusTimerActive || store.focusTimerPaused) ? store.focusProgress : 0)
                            .stroke(phaseColor(store.pomodoroPhase), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: store.focusProgress)

                        VStack(spacing: 4) {
                            Text((store.focusTimerActive || store.focusTimerPaused) ? store.focusTimerDisplay : "\(store.currentPhaseDuration):00")
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundStyle(phaseColor(store.pomodoroPhase))
                            Text(store.focusTimerActive ? store.pomodoroPhase.rawValue : (store.focusTimerPaused ? "Paused" : "Ready"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !store.focusTimerActive && !store.focusTimerPaused {
                        // Session length picker
                        HStack(spacing: 12) {
                            ForEach([15, 25, 45, 60], id: \.self) { mins in
                                Button {
                                    store.send(.focusSessionLengthChanged(mins))
                                } label: {
                                    Text("\(mins)m")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            store.focusSessionMinutes == mins
                                                ? Color.axisGold.opacity(0.2)
                                                : Color.clear
                                        )
                                        .foregroundStyle(
                                            store.focusSessionMinutes == mins
                                                ? Color.axisGold
                                                : .secondary
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Controls
                    HStack(spacing: 10) {
                        Button {
                            if store.focusTimerActive || store.focusTimerPaused {
                                store.send(.stopFocusTimer)
                            } else {
                                store.send(.startFocusTimer)
                            }
                        } label: {
                            HStack {
                                Image(systemName: (store.focusTimerActive || store.focusTimerPaused) ? "stop.fill" : "play.fill")
                                Text((store.focusTimerActive || store.focusTimerPaused) ? "Stop" : "Start Focus")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background((store.focusTimerActive || store.focusTimerPaused) ? Color.red.opacity(0.15) : Color.axisGold.opacity(0.15))
                            .foregroundStyle((store.focusTimerActive || store.focusTimerPaused) ? .red : Color.axisGold)
                            .clipShape(RoundedRectangle(cornerRadius: AxisTheme.buttonRadius))
                        }

                        if store.focusTimerActive || store.focusTimerPaused {
                            Button {
                                store.send(.pauseResumeFocusTimer)
                            } label: {
                                HStack {
                                    Image(systemName: store.focusTimerActive ? "pause.fill" : "play.fill")
                                    Text(store.focusTimerActive ? "Pause" : "Resume")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: AxisTheme.buttonRadius))
                            }
                        }
                    }

                    // Skip break button
                    if store.pomodoroPhase != .work && !store.focusTimerActive && !store.focusTimerPaused {
                        Button {
                            store.send(.skipBreak)
                        } label: {
                            Text("Skip Break")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Options row
                    HStack(spacing: 16) {
                        Toggle(isOn: Binding(
                            get: { store.autoStartNextSession },
                            set: { store.send(.setAutoStartNextSession($0)) }
                        )) {
                            Text("Auto-start")
                                .font(.caption)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)

                        Spacer()

                        // Ambient sound button
                        Button {
                            store.send(.toggleAmbientMixer)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.ambientSounds.isEmpty ? "speaker.slash" : "speaker.wave.2.fill")
                                Text(store.ambientSounds.isEmpty ? "Sounds" : "\(store.ambientSounds.count)")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            if !store.completedFocusSessions.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent Focus Sessions")
                                .font(.headline)
                            Spacer()
                            Button("Clear") {
                                store.send(.clearFocusHistory)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        ForEach(store.completedFocusSessions.prefix(5)) { session in
                            HStack {
                                Circle()
                                    .fill(session.sessionType == "work" ? Color.axisGold : (session.sessionType == "shortBreak" ? Color.green : Color.blue))
                                    .frame(width: 6, height: 6)
                                Text("\(session.durationMinutes) min")
                                    .font(.subheadline)
                                if let pid = session.projectId,
                                   let project = store.projects.first(where: { $0.id == pid }) {
                                    Text("- \(project.title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Focus tips
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Focus Tips")
                            .font(.headline)
                    }
                    Text("Close notifications, put your phone face-down, and commit to one task for the full session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }
        }
    }

    private func phaseColor(_ phase: WorkSuiteReducer.State.PomodoroPhase) -> Color {
        switch phase {
        case .work: return Color.axisGold
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    // MARK: - Add Project Sheet

    private var addProjectSheet: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project title", text: $store.newProjectTitle.sending(\.newProjectTitleChanged))

                    Picker("Priority", selection: $store.newProjectPriority.sending(\.newProjectPriorityChanged)) {
                        Text("High").tag("high")
                        Text("Medium").tag("medium")
                        Text("Low").tag("low")
                    }

                    Toggle("Set Due Date", isOn: Binding(
                        get: { store.newProjectDueDate != nil },
                        set: { enabled in
                            store.send(.newProjectDueDateChanged(enabled ? Date().addingTimeInterval(604800) : nil))
                        }
                    ))

                    if let dueDate = store.newProjectDueDate {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate },
                            set: { store.send(.newProjectDueDateChanged($0)) }
                        ), displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: store.selectedWorkspace.icon)
                        Text("Adding to \(store.selectedWorkspace.rawValue)")
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddProject) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addProject) }
                        .fontWeight(.semibold)
                        .disabled(store.newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}


#Preview {
    WorkSuiteView(
        store: Store(initialState: WorkSuiteReducer.State()) {
            WorkSuiteReducer()
        }
    )
}
