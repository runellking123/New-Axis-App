import ComposableArchitecture
import Foundation

@Reducer
struct WorkSuiteReducer {
    @ObservableState
    struct State: Equatable {
        var selectedWorkspace: Workspace = .wiley
        var projects: [ProjectState] = []
        var showAddProject = false
        var newProjectTitle = ""
        var newProjectPriority = "medium"
        var newProjectDueDate: Date?
        var focusTimerActive = false
        var focusTimerPaused = false
        var focusTimerSeconds: Int = 0
        var focusSessionMinutes: Int = 25
        var completedFocusSessions: [FocusSession] = []
        var selectedSegment: Segment = .projects
        var projectSort: ProjectSort = .priority

        struct FocusSession: Equatable, Identifiable {
            let id: UUID
            let completedAt: Date
            let durationMinutes: Int
        }

        enum ProjectSort: String, CaseIterable, Equatable {
            case priority = "Priority"
            case dueDate = "Due Date"
            case newest = "Newest"
        }

        enum Workspace: String, CaseIterable, Equatable {
            case wiley = "Wiley"
            case consulting = "Consulting"

            var icon: String {
                switch self {
                case .wiley: return "building.columns.fill"
                case .consulting: return "briefcase.fill"
                }
            }

            var key: String {
                switch self {
                case .wiley: return "wiley"
                case .consulting: return "consulting"
                }
            }
        }

        enum Segment: String, CaseIterable, Equatable {
            case projects = "Projects"
            case focus = "Focus"
        }

        struct ProjectState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var workspace: String
            var status: String
            var priority: String
            var notes: String
            var dueDate: Date?

            var priorityColor: String {
                switch priority {
                case "high": return "red"
                case "medium": return "orange"
                case "low": return "green"
                default: return "gray"
                }
            }
        }

        var filteredProjects: [ProjectState] {
            projects.filter { $0.workspace == selectedWorkspace.key }
        }

        var sortedFilteredProjects: [ProjectState] {
            let scoped = filteredProjects
            switch projectSort {
            case .priority:
                let rank: [String: Int] = ["high": 0, "medium": 1, "low": 2]
                return scoped.sorted {
                    let lhs = rank[$0.priority, default: 99]
                    let rhs = rank[$1.priority, default: 99]
                    if lhs != rhs { return lhs < rhs }
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            case .dueDate:
                return scoped.sorted {
                    switch ($0.dueDate, $1.dueDate) {
                    case let (l?, r?): return l < r
                    case (.some, .none): return true
                    case (.none, .some): return false
                    case (.none, .none): return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                }
            case .newest:
                return scoped.reversed()
            }
        }

        var activeProjectCount: Int {
            filteredProjects.filter { $0.status == "active" }.count
        }

        var completedProjectCount: Int {
            filteredProjects.filter { $0.status == "completed" }.count
        }

        var focusTimerDisplay: String {
            let mins = focusTimerSeconds / 60
            let secs = focusTimerSeconds % 60
            return String(format: "%02d:%02d", mins, secs)
        }

        var focusProgress: Double {
            guard focusSessionMinutes > 0 else { return 0 }
            let total = focusSessionMinutes * 60
            let elapsed = total - focusTimerSeconds
            return Double(elapsed) / Double(total)
        }
    }

    enum Action: Equatable {
        case onAppear
        case workspaceChanged(State.Workspace)
        case segmentChanged(State.Segment)
        case toggleAddProject
        case newProjectTitleChanged(String)
        case newProjectPriorityChanged(String)
        case newProjectDueDateChanged(Date?)
        case addProject
        case toggleProjectStatus(UUID)
        case deleteProject(UUID)
        case startFocusTimer
        case pauseResumeFocusTimer
        case stopFocusTimer
        case focusTimerTick
        case focusSessionLengthChanged(Int)
        case clearFocusHistory
        case projectSortChanged(State.ProjectSort)
    }

    @Dependency(\.continuousClock) var clock

    private enum FocusTimerID { case timer }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                let profile = persistence.getOrCreateProfile()
                state.focusSessionMinutes = profile.defaultFocusMinutes
                HapticService.setEnabled(profile.hapticFeedbackEnabled)
                let stored = persistence.fetchWorkProjects()
                if stored.isEmpty {
                    // Seed sample data
                    let samples = Self.sampleProjects()
                    for s in samples {
                        let project = WorkProject(title: s.title, workspace: s.workspace, status: s.status, priority: s.priority, notes: s.notes, dueDate: s.dueDate)
                        persistence.saveWorkProject(project)
                        state.projects.append(State.ProjectState(id: project.uuid, title: project.title, workspace: project.workspace, status: project.status, priority: project.priority, notes: project.notes, dueDate: project.dueDate))
                    }
                } else {
                    state.projects = stored.map { p in
                        State.ProjectState(id: p.uuid, title: p.title, workspace: p.workspace, status: p.status, priority: p.priority, notes: p.notes, dueDate: p.dueDate)
                    }
                }
                return .none

            case let .workspaceChanged(workspace):
                state.selectedWorkspace = workspace
                HapticService.selection()
                return .none

            case let .segmentChanged(segment):
                state.selectedSegment = segment
                return .none

            case .toggleAddProject:
                state.showAddProject.toggle()
                if state.showAddProject {
                    state.newProjectTitle = ""
                    state.newProjectPriority = "medium"
                    state.newProjectDueDate = nil
                }
                return .none

            case let .newProjectTitleChanged(title):
                state.newProjectTitle = title
                return .none

            case let .newProjectPriorityChanged(priority):
                state.newProjectPriority = priority
                return .none

            case let .newProjectDueDateChanged(date):
                state.newProjectDueDate = date
                return .none

            case .addProject:
                guard !state.newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .none
                }
                let project = WorkProject(
                    title: state.newProjectTitle,
                    workspace: state.selectedWorkspace.key,
                    status: "active",
                    priority: state.newProjectPriority,
                    dueDate: state.newProjectDueDate
                )
                PersistenceService.shared.saveWorkProject(project)
                state.projects.append(State.ProjectState(
                    id: project.uuid,
                    title: project.title,
                    workspace: project.workspace,
                    status: project.status,
                    priority: project.priority,
                    notes: project.notes,
                    dueDate: project.dueDate
                ))
                state.showAddProject = false
                state.newProjectTitle = ""
                HapticService.notification(.success)
                return .none

            case let .toggleProjectStatus(id):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].status = state.projects[index].status == "completed" ? "active" : "completed"
                    // Persist
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchWorkProjects()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.status = state.projects[index].status
                        persistence.updateWorkProjects()
                    }
                    HapticService.impact(.light)
                }
                return .none

            case let .deleteProject(id):
                state.projects.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchWorkProjects()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteWorkProject(match)
                }
                return .none

            case .startFocusTimer:
                if state.focusTimerPaused && state.focusTimerSeconds > 0 {
                    state.focusTimerPaused = false
                } else {
                    state.focusTimerActive = true
                    state.focusTimerPaused = false
                    state.focusTimerSeconds = state.focusSessionMinutes * 60
                }
                HapticService.impact(.heavy)
                return .run { send in
                    for await _ in self.clock.timer(interval: .seconds(1)) {
                        await send(.focusTimerTick)
                    }
                }
                .cancellable(id: FocusTimerID.timer)

            case .pauseResumeFocusTimer:
                if state.focusTimerActive {
                    state.focusTimerPaused = true
                    return .cancel(id: FocusTimerID.timer)
                } else if state.focusTimerPaused && state.focusTimerSeconds > 0 {
                    state.focusTimerPaused = false
                    state.focusTimerActive = true
                    return .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.focusTimerTick)
                        }
                    }
                    .cancellable(id: FocusTimerID.timer)
                }
                return .none

            case .stopFocusTimer:
                state.focusTimerActive = false
                state.focusTimerPaused = false
                state.focusTimerSeconds = 0
                return .cancel(id: FocusTimerID.timer)

            case .focusTimerTick:
                guard state.focusTimerActive else { return .none }
                if state.focusTimerSeconds > 0 {
                    state.focusTimerSeconds -= 1
                } else {
                    state.focusTimerActive = false
                    state.focusTimerPaused = false
                    state.completedFocusSessions.insert(
                        .init(id: UUID(), completedAt: Date(), durationMinutes: state.focusSessionMinutes),
                        at: 0
                    )
                    HapticService.celebration()
                    return .cancel(id: FocusTimerID.timer)
                }
                return .none

            case let .focusSessionLengthChanged(minutes):
                state.focusSessionMinutes = minutes
                return .none

            case .clearFocusHistory:
                state.completedFocusSessions = []
                return .none

            case let .projectSortChanged(sort):
                state.projectSort = sort
                return .none
            }
        }
    }

    private static func sampleProjects() -> [State.ProjectState] {
        [
            .init(id: UUID(), title: "IPEDS Fall Enrollment Report", workspace: "wiley", status: "active", priority: "high", notes: "", dueDate: nil),
            .init(id: UUID(), title: "Dashboard KPI Refresh", workspace: "wiley", status: "active", priority: "medium", notes: "", dueDate: nil),
            .init(id: UUID(), title: "SACSCOC Data Review", workspace: "wiley", status: "active", priority: "high", notes: "", dueDate: nil),
            .init(id: UUID(), title: "HTAnalytics API Updates", workspace: "consulting", status: "active", priority: "medium", notes: "", dueDate: nil),
            .init(id: UUID(), title: "Blackbaud Integration", workspace: "consulting", status: "active", priority: "high", notes: "", dueDate: nil),
        ]
    }
}
