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
        var completedFocusSessions: [FocusSessionState] = []
        var selectedSegment: Segment = .projects
        var projectSort: ProjectSort = .priority
        var selectedProjectId: UUID?

        // Phase 1: Enhanced Pomodoro
        var pomodoroPhase: PomodoroPhase = .work
        var completedPomodorosInCycle: Int = 0
        var autoStartNextSession: Bool = false
        var activeProjectForFocus: UUID?
        var shortBreakMinutes: Int = 5
        var longBreakMinutes: Int = 15
        var pomodorosBeforeLongBreak: Int = 4

        // Phase 1: Ambient Sounds
        var ambientSounds: [String: Float] = [:]
        var focusProfiles: [FocusProfileState] = []
        var showAmbientMixer = false
        var showSaveProfile = false
        var newProfileName = ""

        enum PomodoroPhase: String, CaseIterable, Equatable {
            case work = "Work"
            case shortBreak = "Short Break"
            case longBreak = "Long Break"

            var color: String {
                switch self {
                case .work: return "axisGold"
                case .shortBreak: return "green"
                case .longBreak: return "blue"
                }
            }
        }

        struct FocusProfileState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var durationMinutes: Int
            var soundVolumes: [String: Float]
        }

        struct FocusSessionState: Equatable, Identifiable {
            let id: UUID
            let completedAt: Date
            let durationMinutes: Int
            let projectId: UUID?
            let sessionType: String

            init(id: UUID, completedAt: Date, durationMinutes: Int, projectId: UUID? = nil, sessionType: String = "work") {
                self.id = id
                self.completedAt = completedAt
                self.durationMinutes = durationMinutes
                self.projectId = projectId
                self.sessionType = sessionType
            }
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

        struct SubtaskState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var isCompleted: Bool
            var sortOrder: Int
        }

        struct ProjectState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var workspace: String
            var status: String
            var priority: String
            var notes: String
            var dueDate: Date?
            var estimatedPomodoros: Int
            var subtasks: [SubtaskState]

            init(id: UUID, title: String, workspace: String, status: String, priority: String, notes: String, dueDate: Date?, estimatedPomodoros: Int = 0, subtasks: [SubtaskState] = []) {
                self.id = id
                self.title = title
                self.workspace = workspace
                self.status = status
                self.priority = priority
                self.notes = notes
                self.dueDate = dueDate
                self.estimatedPomodoros = estimatedPomodoros
                self.subtasks = subtasks
            }

            var priorityColor: String {
                switch priority {
                case "high": return "red"
                case "medium": return "orange"
                case "low": return "green"
                default: return "gray"
                }
            }

            var subtaskProgress: Double {
                guard !subtasks.isEmpty else { return 0 }
                let completed = subtasks.filter(\.isCompleted).count
                return Double(completed) / Double(subtasks.count)
            }

            var completedSubtaskCount: Int {
                subtasks.filter(\.isCompleted).count
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
            let total = currentPhaseDuration * 60
            guard total > 0 else { return 0 }
            let elapsed = total - focusTimerSeconds
            return Double(elapsed) / Double(total)
        }

        var currentPhaseDuration: Int {
            switch pomodoroPhase {
            case .work: return focusSessionMinutes
            case .shortBreak: return shortBreakMinutes
            case .longBreak: return longBreakMinutes
            }
        }

        // Time logging: total focus minutes per project (today)
        var projectTimeSummary: [UUID: Int] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var summary: [UUID: Int] = [:]
            for session in completedFocusSessions {
                guard session.sessionType == "work",
                      let pid = session.projectId,
                      session.completedAt >= today else { continue }
                summary[pid, default: 0] += session.durationMinutes
            }
            return summary
        }

        var totalFocusMinutesToday: Int {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return completedFocusSessions
                .filter { $0.sessionType == "work" && $0.completedAt >= today }
                .reduce(0) { $0 + $1.durationMinutes }
        }

        var totalFocusMinutesThisWeek: Int {
            let calendar = Calendar.current
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            return completedFocusSessions
                .filter { $0.sessionType == "work" && $0.completedAt >= weekStart }
                .reduce(0) { $0 + $1.durationMinutes }
        }
    }

    enum Action: Equatable {
        case onAppear
        case workspaceChanged(State.Workspace)
        case segmentChanged(State.Segment)
        case toggleAddProject
        case dismissAddProject
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
        // Drill-down
        case selectProject(UUID?)
        case updateProjectTitle(UUID, String)
        case updateProjectPriority(UUID, String)
        case updateProjectNotes(UUID, String)
        // Phase 1: Subtasks
        case addSubtask(UUID, String)
        case toggleSubtask(UUID, UUID) // projectId, subtaskId
        case deleteSubtask(UUID, UUID)
        case updateProjectEstimatedPomodoros(UUID, Int)
        // Phase 1: Enhanced Pomodoro
        case setAutoStartNextSession(Bool)
        case setActiveProjectForFocus(UUID?)
        case pomodoroPhaseCompleted
        case skipBreak
        // Phase 1: Ambient Sounds
        case toggleAmbientMixer
        case dismissAmbientMixer
        case setAmbientVolume(String, Float)
        case stopAllSounds
        case loadFocusProfile(UUID)
        case saveFocusProfile
        case deleteFocusProfile(UUID)
        case newProfileNameChanged(String)
        case toggleSaveProfile
        case dismissSaveProfile
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
                state.projects = stored.map { p in
                    let subtasks = persistence.fetchSubtasks(forProject: p.uuid).map { s in
                        State.SubtaskState(id: s.uuid, title: s.title, isCompleted: s.isCompleted, sortOrder: s.sortOrder)
                    }
                    return State.ProjectState(
                        id: p.uuid, title: p.title, workspace: p.workspace,
                        status: p.status, priority: p.priority, notes: p.notes,
                        dueDate: p.dueDate, estimatedPomodoros: p.estimatedPomodoros ?? 0,
                        subtasks: subtasks
                    )
                }
                let sessions = persistence.fetchFocusSessions()
                state.completedFocusSessions = sessions.map { s in
                    State.FocusSessionState(id: s.uuid, completedAt: s.completedAt, durationMinutes: s.durationMinutes, projectId: s.projectId, sessionType: s.sessionType)
                }
                // Load focus profiles
                let profiles = persistence.fetchFocusProfiles()
                state.focusProfiles = profiles.map { p in
                    State.FocusProfileState(id: p.uuid, name: p.name, durationMinutes: p.durationMinutes, soundVolumes: p.soundVolumes)
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

            case .dismissAddProject:
                state.showAddProject = false
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
                // Also delete subtasks for this project
                let subtasks = persistence.fetchSubtasks(forProject: id)
                for s in subtasks { persistence.deleteSubtask(s) }
                return .none

            case .startFocusTimer:
                if state.focusTimerPaused && state.focusTimerSeconds > 0 {
                    state.focusTimerPaused = false
                } else {
                    state.focusTimerActive = true
                    state.focusTimerPaused = false
                    state.focusTimerSeconds = state.currentPhaseDuration * 60
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
                    state.focusTimerActive = false
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
                state.pomodoroPhase = .work
                state.completedPomodorosInCycle = 0
                AudioService.shared.stopAll()
                return .cancel(id: FocusTimerID.timer)

            case .focusTimerTick:
                guard state.focusTimerActive else { return .none }
                if state.focusTimerSeconds > 0 {
                    state.focusTimerSeconds -= 1
                } else {
                    return .send(.pomodoroPhaseCompleted)
                }
                return .none

            case .pomodoroPhaseCompleted:
                state.focusTimerActive = false
                state.focusTimerPaused = false
                HapticService.celebration()

                switch state.pomodoroPhase {
                case .work:
                    // Save completed work session
                    let session = FocusSession(
                        durationMinutes: state.focusSessionMinutes,
                        projectId: state.activeProjectForFocus,
                        sessionType: "work",
                        completedPomodoros: 1
                    )
                    PersistenceService.shared.saveFocusSession(session)
                    state.completedFocusSessions.insert(
                        .init(id: session.uuid, completedAt: session.completedAt, durationMinutes: session.durationMinutes, projectId: session.projectId, sessionType: session.sessionType),
                        at: 0
                    )
                    state.completedPomodorosInCycle += 1

                    // Decide next phase
                    if state.completedPomodorosInCycle >= state.pomodorosBeforeLongBreak {
                        state.pomodoroPhase = .longBreak
                        state.completedPomodorosInCycle = 0
                    } else {
                        state.pomodoroPhase = .shortBreak
                    }

                case .shortBreak, .longBreak:
                    state.pomodoroPhase = .work
                }

                // Auto-start next session if enabled
                if state.autoStartNextSession {
                    state.focusTimerSeconds = state.currentPhaseDuration * 60
                    state.focusTimerActive = true
                    return .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.focusTimerTick)
                        }
                    }
                    .cancellable(id: FocusTimerID.timer)
                }

                return .cancel(id: FocusTimerID.timer)

            case .skipBreak:
                guard state.pomodoroPhase != .work else { return .none }
                state.pomodoroPhase = .work
                state.focusTimerActive = false
                state.focusTimerPaused = false
                state.focusTimerSeconds = 0
                if state.autoStartNextSession {
                    return .send(.startFocusTimer)
                }
                return .cancel(id: FocusTimerID.timer)

            case let .focusSessionLengthChanged(minutes):
                state.focusSessionMinutes = minutes
                return .none

            case .clearFocusHistory:
                state.completedFocusSessions = []
                return .none

            case let .projectSortChanged(sort):
                state.projectSort = sort
                return .none

            // MARK: - Drill-down

            case let .selectProject(id):
                state.selectedProjectId = id
                return .none

            case let .updateProjectTitle(id, title):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].title = title
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchWorkProjects()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.title = title
                        persistence.updateWorkProjects()
                    }
                }
                return .none

            case let .updateProjectPriority(id, priority):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].priority = priority
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchWorkProjects()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.priority = priority
                        persistence.updateWorkProjects()
                    }
                }
                return .none

            case let .updateProjectNotes(id, notes):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].notes = notes
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchWorkProjects()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.notes = notes
                        persistence.updateWorkProjects()
                    }
                }
                return .none

            // MARK: - Subtasks

            case let .addSubtask(projectId, title):
                guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                if let index = state.projects.firstIndex(where: { $0.id == projectId }) {
                    let sortOrder = state.projects[index].subtasks.count
                    let subtask = Subtask(title: title, projectId: projectId, sortOrder: sortOrder)
                    PersistenceService.shared.saveSubtask(subtask)
                    state.projects[index].subtasks.append(
                        State.SubtaskState(id: subtask.uuid, title: subtask.title, isCompleted: false, sortOrder: sortOrder)
                    )
                    HapticService.impact(.light)
                }
                return .none

            case let .toggleSubtask(projectId, subtaskId):
                if let pIndex = state.projects.firstIndex(where: { $0.id == projectId }),
                   let sIndex = state.projects[pIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    state.projects[pIndex].subtasks[sIndex].isCompleted.toggle()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSubtasks(forProject: projectId)
                    if let match = stored.first(where: { $0.uuid == subtaskId }) {
                        match.isCompleted = state.projects[pIndex].subtasks[sIndex].isCompleted
                        persistence.updateSubtasks()
                    }
                    HapticService.impact(.light)
                }
                return .none

            case let .deleteSubtask(projectId, subtaskId):
                if let pIndex = state.projects.firstIndex(where: { $0.id == projectId }) {
                    state.projects[pIndex].subtasks.removeAll { $0.id == subtaskId }
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchSubtasks(forProject: projectId)
                    if let match = stored.first(where: { $0.uuid == subtaskId }) {
                        persistence.deleteSubtask(match)
                    }
                }
                return .none

            case let .updateProjectEstimatedPomodoros(id, count):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].estimatedPomodoros = count
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchWorkProjects()
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.estimatedPomodoros = count
                        persistence.updateWorkProjects()
                    }
                }
                return .none

            // MARK: - Enhanced Pomodoro

            case let .setAutoStartNextSession(enabled):
                state.autoStartNextSession = enabled
                return .none

            case let .setActiveProjectForFocus(id):
                state.activeProjectForFocus = id
                return .none

            // MARK: - Ambient Sounds

            case .toggleAmbientMixer:
                state.showAmbientMixer.toggle()
                return .none

            case .dismissAmbientMixer:
                state.showAmbientMixer = false
                return .none

            case let .setAmbientVolume(sound, volume):
                if volume <= 0 {
                    state.ambientSounds.removeValue(forKey: sound)
                } else {
                    state.ambientSounds[sound] = volume
                }
                AudioService.shared.setVolume(sound, volume: volume)
                return .none

            case .stopAllSounds:
                state.ambientSounds = [:]
                AudioService.shared.stopAll()
                return .none

            case let .loadFocusProfile(id):
                if let profile = state.focusProfiles.first(where: { $0.id == id }) {
                    state.focusSessionMinutes = profile.durationMinutes
                    // Stop existing sounds
                    AudioService.shared.stopAll()
                    state.ambientSounds = profile.soundVolumes
                    for (sound, volume) in profile.soundVolumes {
                        AudioService.shared.setVolume(sound, volume: volume)
                    }
                    HapticService.impact(.light)
                }
                return .none

            case .saveFocusProfile:
                guard !state.newProfileName.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                let profile = FocusProfile(
                    name: state.newProfileName,
                    durationMinutes: state.focusSessionMinutes,
                    soundVolumes: state.ambientSounds
                )
                PersistenceService.shared.saveFocusProfile(profile)
                state.focusProfiles.append(
                    State.FocusProfileState(id: profile.uuid, name: profile.name, durationMinutes: profile.durationMinutes, soundVolumes: profile.soundVolumes)
                )
                state.showSaveProfile = false
                state.newProfileName = ""
                HapticService.notification(.success)
                return .none

            case let .deleteFocusProfile(id):
                state.focusProfiles.removeAll { $0.id == id }
                let persistence = PersistenceService.shared
                let stored = persistence.fetchFocusProfiles()
                if let match = stored.first(where: { $0.uuid == id }) {
                    persistence.deleteFocusProfile(match)
                }
                return .none

            case let .newProfileNameChanged(name):
                state.newProfileName = name
                return .none

            case .toggleSaveProfile:
                state.showSaveProfile.toggle()
                if state.showSaveProfile {
                    state.newProfileName = ""
                }
                return .none

            case .dismissSaveProfile:
                state.showSaveProfile = false
                return .none
            }
        }
    }

}
