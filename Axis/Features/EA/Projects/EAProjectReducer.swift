import ComposableArchitecture
import Foundation

@Reducer
struct EAProjectReducer {
    @ObservableState
    struct State: Equatable {
        var projects: [ProjectState] = []
        var selectedView: ProjectView = .list
        var templates: [TemplateState] = []
        var naturalLanguageInput: String = ""
        var scaffoldedPreview: ScaffoldedPreviewState?
        var isScaffolding: Bool = false
        var selectedProjectId: UUID?
        var filterStatus: String = "all"
        var filterCategory: String = "all"
        var searchText: String = ""
        var showCreateProject: Bool = false
        var newProjectTitle: String = ""
        var newProjectCategory: String = "personal"
        var newProjectDescription: String = ""

        enum ProjectView: String, CaseIterable, Equatable {
            case list = "List"
            case kanban = "Kanban"
        }

        struct ProjectState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var projectDescription: String?
            var status: String
            var category: String
            var deadline: Date?
            var tasks: [TaskState]
            var milestones: [MilestoneState]

            var progress: Double {
                guard !tasks.isEmpty else { return 0 }
                let completed = tasks.filter { $0.status == "completed" }.count
                return Double(completed) / Double(tasks.count)
            }

            var completedTaskCount: Int {
                tasks.filter { $0.status == "completed" }.count
            }

            var hasAtRiskDependencies: Bool {
                tasks.contains { task in
                    guard let deadline = task.deadline else { return false }
                    let hoursUntil = deadline.timeIntervalSince(Date()) / 3600
                    return hoursUntil < 72 && task.status != "completed"
                }
            }
        }

        struct TaskState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var status: String
            var priority: String
            var deadline: Date?
            var estimatedMinutes: Int?
        }

        struct MilestoneState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var dueDate: Date?
            var isCompleted: Bool
            var sortOrder: Int
        }

        struct TemplateState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var taskCount: Int
            var category: String
        }

        struct ScaffoldedPreviewState: Equatable {
            var title: String
            var description: String?
            var subtasks: [ScaffoldedTaskPreview]
            var milestones: [ScaffoldedMilestonePreview]
            var estimatedDays: Int?
            var category: String
        }

        struct ScaffoldedTaskPreview: Equatable, Identifiable {
            let id = UUID()
            var title: String
            var priority: String
            var estimatedMinutes: Int?
        }

        struct ScaffoldedMilestonePreview: Equatable, Identifiable {
            let id = UUID()
            var title: String
            var relativeDayOffset: Int
        }

        var filteredProjects: [ProjectState] {
            var result = projects
            if filterStatus != "all" {
                result = result.filter { $0.status == filterStatus }
            }
            if filterCategory != "all" {
                result = result.filter { $0.category == filterCategory }
            }
            if !searchText.isEmpty {
                result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            }
            return result
        }

        // Kanban columns
        var backlogTasks: [TaskState] {
            projects.flatMap(\.tasks).filter { $0.status == "inbox" || $0.status == "scheduled" }
        }
        var inProgressTasks: [TaskState] {
            projects.flatMap(\.tasks).filter { $0.status == "inProgress" }
        }
        var reviewTasks: [TaskState] {
            projects.flatMap(\.tasks).filter { $0.status == "review" }
        }
        var doneTasks: [TaskState] {
            projects.flatMap(\.tasks).filter { $0.status == "completed" }
        }
    }

    enum Action: Equatable {
        case onAppear
        case projectsLoaded([State.ProjectState])
        case viewChanged(State.ProjectView)
        case filterStatusChanged(String)
        case filterCategoryChanged(String)
        case searchTextChanged(String)
        case selectProject(UUID?)
        case naturalLanguageInputChanged(String)
        case scaffoldWithAI
        case scaffoldPreviewLoaded(State.ScaffoldedPreviewState?)
        case confirmScaffold
        case cancelScaffold
        case createProject(String, String, String) // title, category, status
        case showCreateProjectSheet
        case dismissCreateProjectSheet
        case newProjectTitleChanged(String)
        case newProjectCategoryChanged(String)
        case newProjectDescriptionChanged(String)
        case confirmCreateProject
        case deleteProject(UUID)
        case updateProjectStatus(UUID, String)
        case moveTask(UUID, String) // taskId, newStatus (kanban)
        case addTaskToProject(projectId: UUID, title: String, priority: String, estimatedMinutes: Int?)
        case toggleProjectTaskStatus(projectId: UUID, taskId: UUID)
        case addMilestoneToProject(projectId: UUID, title: String, dueDate: Date?)
        case toggleMilestoneCompletion(projectId: UUID, milestoneId: UUID)
        case saveAsTemplate(UUID)
        case createFromTemplate(UUID)
    }

    @Dependency(\.axisHaptics) var haptics
    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let taskModels = persistence.fetchEATasks()
                    let projectStates = persistence.fetchEAProjects().map { project in
                        let tasks = taskModels
                            .filter { $0.projectId == project.uuid }
                            .map(Self.taskState(from:))
                        let milestones = persistence.fetchEAMilestones(project.uuid).map(Self.milestoneState(from:))
                        return Self.projectState(from: project, tasks: tasks, milestones: milestones)
                    }
                    await send(.projectsLoaded(projectStates))
                }

            case let .projectsLoaded(projects):
                state.projects = projects
                return .none

            case let .viewChanged(view):
                state.selectedView = view
                return .none

            case let .filterStatusChanged(status):
                state.filterStatus = status
                return .none

            case let .filterCategoryChanged(category):
                state.filterCategory = category
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                return .none

            case let .selectProject(id):
                state.selectedProjectId = id
                return .none

            case let .naturalLanguageInputChanged(text):
                state.naturalLanguageInput = text
                return .none

            case .scaffoldWithAI:
                let input = state.naturalLanguageInput
                guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                state.isScaffolding = true

                let result = AIExecutiveService.shared.scaffoldProject(description: input)
                state.scaffoldedPreview = State.ScaffoldedPreviewState(
                    title: result.title,
                    description: result.description,
                    subtasks: result.subtasks.map { .init(title: $0.title, priority: $0.priority, estimatedMinutes: $0.estimatedMinutes) },
                    milestones: result.milestones.map { .init(title: $0.title, relativeDayOffset: $0.relativeDayOffset) },
                    estimatedDays: result.estimatedDays,
                    category: result.category
                )
                state.isScaffolding = false
                return .none

            case let .scaffoldPreviewLoaded(preview):
                state.scaffoldedPreview = preview
                state.isScaffolding = false
                return .none

            case .confirmScaffold:
                guard let preview = state.scaffoldedPreview else { return .none }
                let projectId = UUID()
                let tasks = preview.subtasks.map { subtask in
                    State.TaskState(
                        id: UUID(),
                        title: subtask.title,
                        status: "inbox",
                        priority: subtask.priority,
                        deadline: nil,
                        estimatedMinutes: subtask.estimatedMinutes
                    )
                }
                let milestones = preview.milestones.enumerated().map { index, ms in
                    State.MilestoneState(
                        id: UUID(),
                        title: ms.title,
                        dueDate: Calendar.current.date(byAdding: .day, value: ms.relativeDayOffset, to: Date()),
                        isCompleted: false,
                        sortOrder: index
                    )
                }
                let project = State.ProjectState(
                    id: projectId,
                    title: preview.title,
                    projectDescription: preview.description,
                    status: "active",
                    category: preview.category,
                    deadline: milestones.last?.dueDate,
                    tasks: tasks,
                    milestones: milestones
                )
                state.projects.insert(project, at: 0)
                let projectModel = EAProject(
                    title: preview.title,
                    projectDescription: preview.description,
                    status: "active",
                    category: preview.category,
                    deadline: milestones.last?.dueDate
                )
                projectModel.uuid = projectId
                persistence.saveEAProject(projectModel)
                for task in preview.subtasks {
                    let taskModel = EATask(
                        title: task.title,
                        priority: task.priority,
                        status: "inbox",
                        category: preview.category,
                        estimatedMinutes: task.estimatedMinutes,
                        projectId: projectId
                    )
                    persistence.saveEATask(taskModel)
                }
                for (index, milestone) in preview.milestones.enumerated() {
                    let milestoneModel = EAMilestone(
                        title: milestone.title,
                        dueDate: Calendar.current.date(byAdding: .day, value: milestone.relativeDayOffset, to: Date()),
                        isCompleted: false,
                        projectId: projectId,
                        sortOrder: index
                    )
                    persistence.saveEAMilestone(milestoneModel)
                }
                state.scaffoldedPreview = nil
                state.naturalLanguageInput = ""
                haptics.notificationSuccess()
                return .none

            case .cancelScaffold:
                state.scaffoldedPreview = nil
                return .none

            case .showCreateProjectSheet:
                state.showCreateProject = true
                state.newProjectTitle = ""
                state.newProjectCategory = "personal"
                state.newProjectDescription = ""
                return .none

            case .dismissCreateProjectSheet:
                state.showCreateProject = false
                return .none

            case let .newProjectTitleChanged(title):
                state.newProjectTitle = title
                return .none

            case let .newProjectCategoryChanged(category):
                state.newProjectCategory = category
                return .none

            case let .newProjectDescriptionChanged(desc):
                state.newProjectDescription = desc
                return .none

            case .confirmCreateProject:
                let title = state.newProjectTitle.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return .none }
                let projectId = UUID()
                let project = State.ProjectState(
                    id: projectId,
                    title: title,
                    projectDescription: state.newProjectDescription.isEmpty ? nil : state.newProjectDescription,
                    status: "active",
                    category: state.newProjectCategory,
                    deadline: nil,
                    tasks: [],
                    milestones: []
                )
                state.projects.insert(project, at: 0)
                let projectModel = EAProject(
                    title: title,
                    projectDescription: state.newProjectDescription.isEmpty ? nil : state.newProjectDescription,
                    status: "active",
                    category: state.newProjectCategory,
                    deadline: nil
                )
                projectModel.uuid = projectId
                persistence.saveEAProject(projectModel)
                state.showCreateProject = false
                haptics.notificationSuccess()
                return .none

            case let .createProject(title, category, status):
                let project = State.ProjectState(
                    id: UUID(),
                    title: title,
                    projectDescription: nil,
                    status: status,
                    category: category,
                    deadline: nil,
                    tasks: [],
                    milestones: []
                )
                state.projects.insert(project, at: 0)
                haptics.notificationSuccess()
                return .none

            case let .deleteProject(id):
                state.projects.removeAll { $0.id == id }
                persistence.deleteEAProjectById(id)
                for task in persistence.fetchEATasks().filter({ $0.projectId == id }) {
                    persistence.deleteEATaskById(task.uuid)
                }
                for milestone in persistence.fetchEAMilestones(id) {
                    PersistenceService.shared.deleteEAMilestone(milestone)
                }
                return .none

            case let .updateProjectStatus(id, newStatus):
                if let index = state.projects.firstIndex(where: { $0.id == id }) {
                    state.projects[index].status = newStatus
                    let projects = persistence.fetchEAProjects()
                    if let model = projects.first(where: { $0.uuid == id }) {
                        model.status = newStatus
                        persistence.updateEAProjects()
                    }
                    haptics.selection()
                }
                return .none

            case let .moveTask(taskId, newStatus):
                for pIndex in state.projects.indices {
                    if let tIndex = state.projects[pIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                        state.projects[pIndex].tasks[tIndex].status = newStatus
                        let tasks = persistence.fetchEATasks()
                        if let model = tasks.first(where: { $0.uuid == taskId }) {
                            model.status = newStatus
                            persistence.updateEATasks()
                        }
                        haptics.selection()
                        break
                    }
                }
                return .none

            case let .addTaskToProject(projectId, title, priority, estimatedMinutes):
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let taskId = UUID()
                if let index = state.projects.firstIndex(where: { $0.id == projectId }) {
                    state.projects[index].tasks.append(
                        State.TaskState(
                            id: taskId,
                            title: trimmed,
                            status: "inbox",
                            priority: priority,
                            deadline: state.projects[index].deadline,
                            estimatedMinutes: estimatedMinutes
                        )
                    )
                }
                let model = EATask(
                    title: trimmed,
                    deadline: state.projects.first(where: { $0.id == projectId })?.deadline,
                    priority: priority,
                    energyLevel: "lightWork",
                    status: "inbox",
                    category: state.projects.first(where: { $0.id == projectId })?.category ?? "personal",
                    estimatedMinutes: estimatedMinutes,
                    projectId: projectId
                )
                model.uuid = taskId
                persistence.saveEATask(model)
                haptics.notificationSuccess()
                return .none

            case let .toggleProjectTaskStatus(projectId, taskId):
                if let projectIndex = state.projects.firstIndex(where: { $0.id == projectId }),
                   let taskIndex = state.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                    let current = state.projects[projectIndex].tasks[taskIndex].status
                    state.projects[projectIndex].tasks[taskIndex].status = current == "completed" ? "inProgress" : "completed"
                    let tasks = persistence.fetchEATasks()
                    if let model = tasks.first(where: { $0.uuid == taskId }) {
                        model.status = state.projects[projectIndex].tasks[taskIndex].status
                        persistence.updateEATasks()
                    }
                    haptics.selection()
                }
                return .none

            case let .addMilestoneToProject(projectId, title, dueDate):
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let milestoneId = UUID()
                if let index = state.projects.firstIndex(where: { $0.id == projectId }) {
                    let nextSort = (state.projects[index].milestones.map(\.sortOrder).max() ?? -1) + 1
                    state.projects[index].milestones.append(
                        State.MilestoneState(
                            id: milestoneId,
                            title: trimmed,
                            dueDate: dueDate,
                            isCompleted: false,
                            sortOrder: nextSort
                        )
                    )
                }
                let model = EAMilestone(
                    title: trimmed,
                    dueDate: dueDate,
                    isCompleted: false,
                    projectId: projectId,
                    sortOrder: persistence.fetchEAMilestones(projectId).count
                )
                model.uuid = milestoneId
                persistence.saveEAMilestone(model)
                haptics.notificationSuccess()
                return .none

            case let .toggleMilestoneCompletion(projectId, milestoneId):
                if let projectIndex = state.projects.firstIndex(where: { $0.id == projectId }),
                   let milestoneIndex = state.projects[projectIndex].milestones.firstIndex(where: { $0.id == milestoneId }) {
                    state.projects[projectIndex].milestones[milestoneIndex].isCompleted.toggle()
                    let milestones = persistence.fetchEAMilestones(projectId)
                    if let model = milestones.first(where: { $0.uuid == milestoneId }) {
                        model.isCompleted = state.projects[projectIndex].milestones[milestoneIndex].isCompleted
                        PersistenceService.shared.updateEAMilestones()
                    }
                    haptics.selection()
                }
                return .none

            case .saveAsTemplate:
                return .none

            case .createFromTemplate:
                return .none
            }
        }
    }
}

private extension EAProjectReducer {
    static func taskState(from model: EATask) -> State.TaskState {
        State.TaskState(
            id: model.uuid,
            title: model.title,
            status: model.status,
            priority: model.priority,
            deadline: model.deadline,
            estimatedMinutes: model.estimatedMinutes
        )
    }

    static func milestoneState(from model: EAMilestone) -> State.MilestoneState {
        State.MilestoneState(
            id: model.uuid,
            title: model.title,
            dueDate: model.dueDate,
            isCompleted: model.isCompleted,
            sortOrder: model.sortOrder
        )
    }

    static func projectState(
        from model: EAProject,
        tasks: [State.TaskState],
        milestones: [State.MilestoneState]
    ) -> State.ProjectState {
        State.ProjectState(
            id: model.uuid,
            title: model.title,
            projectDescription: model.projectDescription,
            status: model.status,
            category: model.category,
            deadline: model.deadline,
            tasks: tasks,
            milestones: milestones
        )
    }
}
