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
                set: { _ in store.send(.toggleAddProject) }
            )) {
                addProjectSheet
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

            // Active projects
            let active = store.filteredProjects.filter { $0.status == "active" }
            if !active.isEmpty {
                sectionHeader("Active", count: active.count)
                ForEach(active) { project in
                    projectCard(project)
                }
            }

            // Completed projects
            let completed = store.filteredProjects.filter { $0.status == "completed" }
            if !completed.isEmpty {
                sectionHeader("Completed", count: completed.count)
                ForEach(completed) { project in
                    projectCard(project)
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
            // Timer display
            GlassCard {
                VStack(spacing: 20) {
                    Text("Focus Timer")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)

                    ZStack {
                        Circle()
                            .stroke(Color.axisGold.opacity(0.2), lineWidth: 8)
                            .frame(width: 180, height: 180)

                        Circle()
                            .trim(from: 0, to: store.focusTimerActive ? store.focusProgress : 0)
                            .stroke(Color.axisGold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: store.focusProgress)

                        VStack(spacing: 4) {
                            Text(store.focusTimerActive ? store.focusTimerDisplay : "\(store.focusSessionMinutes):00")
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.axisGold)
                            Text(store.focusTimerActive ? "Stay focused" : "Ready")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !store.focusTimerActive {
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

                    Button {
                        if store.focusTimerActive {
                            store.send(.stopFocusTimer)
                        } else {
                            store.send(.startFocusTimer)
                        }
                    } label: {
                        HStack {
                            Image(systemName: store.focusTimerActive ? "stop.fill" : "play.fill")
                            Text(store.focusTimerActive ? "Stop" : "Start Focus")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(store.focusTimerActive ? Color.red.opacity(0.15) : Color.axisGold.opacity(0.15))
                        .foregroundStyle(store.focusTimerActive ? .red : Color.axisGold)
                        .clipShape(RoundedRectangle(cornerRadius: AxisTheme.buttonRadius))
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
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.toggleAddProject) }
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
