import ComposableArchitecture
import SwiftUI

struct ProjectDetailView: View {
    @Bindable var store: StoreOf<WorkSuiteReducer>
    let project: WorkSuiteReducer.State.ProjectState
    @State private var newSubtaskTitle = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status card
                GlassCard {
                    HStack(spacing: 16) {
                        Button {
                            store.send(.toggleProjectStatus(project.id))
                        } label: {
                            Image(systemName: project.status == "completed" ? "checkmark.circle.fill" : "circle")
                                .font(.largeTitle)
                                .foregroundStyle(project.status == "completed" ? .green : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .strikethrough(project.status == "completed")
                            HStack(spacing: 6) {
                                Text(project.status == "completed" ? "Completed" : "Active")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(project.status == "completed" ? Color.green.opacity(0.15) : Color.axisGold.opacity(0.15))
                                    .foregroundStyle(project.status == "completed" ? .green : Color.axisGold)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }

                // Subtasks checklist
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Subtasks")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            if !project.subtasks.isEmpty {
                                Text("\(project.completedSubtaskCount)/\(project.subtasks.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !project.subtasks.isEmpty {
                            ProgressView(value: project.subtaskProgress)
                                .tint(project.subtaskProgress >= 1.0 ? .green : Color.axisGold)

                            ForEach(project.subtasks) { subtask in
                                HStack(spacing: 10) {
                                    Button {
                                        store.send(.toggleSubtask(project.id, subtask.id))
                                    } label: {
                                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                                    }
                                    Text(subtask.title)
                                        .font(.subheadline)
                                        .strikethrough(subtask.isCompleted)
                                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                                    Spacer()
                                    Button {
                                        store.send(.deleteSubtask(project.id, subtask.id))
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Add subtask field
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.axisGold)
                            TextField("Add subtask...", text: $newSubtaskTitle)
                                .font(.subheadline)
                                .onSubmit {
                                    if !newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                        store.send(.addSubtask(project.id, newSubtaskTitle))
                                        newSubtaskTitle = ""
                                    }
                                }
                        }
                        .padding(.top, 4)
                    }
                }

                // Pomodoro Estimation
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pomodoro Estimate")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            ForEach([0, 1, 2, 3, 4, 6, 8], id: \.self) { count in
                                Button {
                                    store.send(.updateProjectEstimatedPomodoros(project.id, count))
                                } label: {
                                    Text(count == 0 ? "-" : "\(count)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 32, height: 32)
                                        .background(project.estimatedPomodoros == count ? Color.axisGold.opacity(0.2) : Color(.systemGray5))
                                        .foregroundStyle(project.estimatedPomodoros == count ? Color.axisGold : .secondary)
                                        .clipShape(Circle())
                                }
                            }
                        }

                        if project.estimatedPomodoros > 0 {
                            let completedMins = store.projectTimeSummary[project.id] ?? 0
                            let sessionLen = store.focusSessionMinutes > 0 ? store.focusSessionMinutes : 25
                            let completedPomos = completedMins / sessionLen
                            HStack {
                                Text("\(completedPomos) of \(project.estimatedPomodoros) completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(completedMins) min logged")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Edit title
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Project title", text: Binding(
                            get: { project.title },
                            set: { store.send(.updateProjectTitle(project.id, $0)) }
                        ))
                        .font(.subheadline)
                    }
                }

                // Priority
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 12) {
                            priorityChip("high", color: .red)
                            priorityChip("medium", color: .orange)
                            priorityChip("low", color: .green)
                        }
                    }
                }

                // Workspace
                GlassCard {
                    HStack {
                        Image(systemName: project.workspace == "wiley" ? "building.columns.fill" : "briefcase.fill")
                            .foregroundStyle(Color.axisGold)
                        Text("Workspace: \(project.workspace.capitalized)")
                            .font(.subheadline)
                        Spacer()
                    }
                }

                // Due Date
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let dueDate = project.dueDate {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(dueDate < Date() ? .red : .blue)
                                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundStyle(dueDate < Date() ? .red : .primary)
                                Spacer()
                                if dueDate < Date() {
                                    Text("OVERDUE")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.red)
                                }
                            }
                        } else {
                            Text("No due date set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Time Log
                let projectSessions = store.completedFocusSessions.filter { $0.projectId == project.id && $0.sessionType == "work" }
                if !projectSessions.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color.axisGold)
                                Text("Time Log")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                let totalMins = projectSessions.reduce(0) { $0 + $1.durationMinutes }
                                Text("\(totalMins) min total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(projectSessions.prefix(10)) { session in
                                HStack {
                                    Text("\(session.durationMinutes) min")
                                        .font(.caption)
                                    Spacer()
                                    Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Add notes...", text: Binding(
                            get: { project.notes },
                            set: { store.send(.updateProjectNotes(project.id, $0)) }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...8)
                    }
                }

                // Delete
                Button(role: .destructive) {
                    store.send(.deleteProject(project.id))
                    store.send(.selectProject(nil))
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Project")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Project")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func priorityChip(_ value: String, color: Color) -> some View {
        Button {
            store.send(.updateProjectPriority(project.id, value))
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(value.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(project.priority == value ? color.opacity(0.15) : Color(.systemGray5))
            .foregroundStyle(project.priority == value ? color : .secondary)
            .clipShape(Capsule())
        }
    }
}

#Preview {
    ProjectDetailView(
        store: Store(initialState: WorkSuiteReducer.State()) {
            WorkSuiteReducer()
        },
        project: WorkSuiteReducer.State.ProjectState(
            id: UUID(),
            title: "Dashboard Redesign",
            workspace: "Engineering",
            status: "active",
            priority: "high",
            notes: "V2 launch",
            dueDate: Date().addingTimeInterval(86400 * 14)
        )
    )
}
