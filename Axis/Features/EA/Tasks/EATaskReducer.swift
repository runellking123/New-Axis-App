import ComposableArchitecture
import Foundation

@Reducer
struct EATaskReducer {
    @ObservableState
    struct State: Equatable {
        var tasks: [TaskState] = []
        var selectedFilter: TaskFilter = .all
        var sortMode: TaskSort = .priority
        var inboxItems: [InboxItemState] = []
        var inboxCount: Int = 0
        var naturalLanguageInput: String = ""
        var parsedPreview: ParsedPreviewState?
        var selectedTaskId: UUID?
        var isAIParsing: Bool = false
        var isSelectMode: Bool = false
        var selectedTaskIds: Set<UUID> = []
        var showAddTask: Bool = false
        var newTaskTitle: String = ""
        var newTaskPriority: String = "medium"
        var newTaskCategory: String = "personal"
        var newTaskDuration: Int = 25

        enum TaskFilter: String, CaseIterable, Equatable {
            case all = "All"
            case inbox = "Inbox"
            case scheduled = "Scheduled"
            case inProgress = "In Progress"
            case done = "Done"
        }

        enum TaskSort: String, CaseIterable, Equatable {
            case priority = "Priority"
            case deadline = "Deadline"
            case newest = "Newest"
        }

        struct TaskState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var deadline: Date?
            var priority: String
            var energyLevel: String
            var status: String
            var category: String
            var estimatedMinutes: Int?
            var scheduledStart: Date?
            var scheduledEnd: Date?
            var projectId: UUID?
            var tags: [String]?
            var aiReasoning: String?
            var isAtRisk: Bool
        }

        struct InboxItemState: Equatable, Identifiable {
            let id: UUID
            var rawInput: String
            var classifiedType: String
            var confidence: Double?
            var isReviewed: Bool
            var createdAt: Date
        }

        struct ParsedPreviewState: Equatable {
            var title: String
            var deadline: Date?
            var priority: String
            var estimatedMinutes: Int?
            var energyLevel: String
            var category: String
        }

        var filteredTasks: [TaskState] {
            let filtered: [TaskState]
            switch selectedFilter {
            case .all: filtered = tasks.filter { $0.status != "cancelled" }
            case .inbox: filtered = tasks.filter { $0.status == "inbox" }
            case .scheduled: filtered = tasks.filter { $0.status == "scheduled" }
            case .inProgress: filtered = tasks.filter { $0.status == "inProgress" }
            case .done: filtered = tasks.filter { $0.status == "completed" }
            }

            switch sortMode {
            case .priority:
                let rank: [String: Int] = ["critical": 0, "high": 1, "medium": 2, "low": 3]
                return filtered.sorted { (rank[$0.priority] ?? 4) < (rank[$1.priority] ?? 4) }
            case .deadline:
                return filtered.sorted {
                    ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture)
                }
            case .newest:
                return filtered.reversed()
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tasksLoaded([State.TaskState])
        case inboxLoaded([State.InboxItemState])
        case filterChanged(State.TaskFilter)
        case sortChanged(State.TaskSort)
        case naturalLanguageInputChanged(String)
        case submitNaturalLanguage
        case parsedPreviewLoaded(State.ParsedPreviewState?)
        case confirmParsedTask
        case cancelParsedTask
        case completeTask(UUID)
        case rescheduleTask(UUID)
        case deleteTask(UUID)
        case selectTask(UUID?)
        case updateTaskStatus(UUID, String)
        case toggleSelectMode
        case toggleTaskSelection(UUID)
        case batchComplete
        case batchDelete
        case selectAll
        case deselectAll
        case showAddTaskSheet
        case dismissAddTaskSheet
        case newTaskTitleChanged(String)
        case newTaskPriorityChanged(String)
        case newTaskCategoryChanged(String)
        case newTaskDurationChanged(Int)
        case confirmNewTask
    }

    @Dependency(\.axisHaptics) var haptics
    @Dependency(\.axisPersistence) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let tasks = persistence.fetchEATasks().map(Self.taskState(from:))
                    await send(.tasksLoaded(tasks))
                    let inboxItems = persistence.fetchEAInboxItems().map(Self.inboxItemState(from:))
                    await send(.inboxLoaded(inboxItems))
                }

            case let .tasksLoaded(tasks):
                state.tasks = tasks
                return .none

            case let .inboxLoaded(items):
                state.inboxItems = items
                state.inboxCount = items.filter { !$0.isReviewed }.count
                return .none

            case let .filterChanged(filter):
                state.selectedFilter = filter
                return .none

            case let .sortChanged(sort):
                state.sortMode = sort
                return .none

            case let .naturalLanguageInputChanged(text):
                state.naturalLanguageInput = text
                return .none

            case .submitNaturalLanguage:
                let input = state.naturalLanguageInput
                guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }

                let parsed = AIExecutiveService.shared.parseTask(input: input)
                let taskId = UUID()
                let newTask = State.TaskState(
                    id: taskId,
                    title: parsed.title,
                    deadline: parsed.deadline,
                    priority: parsed.priority,
                    energyLevel: parsed.energyLevel,
                    status: "inbox",
                    category: parsed.category,
                    estimatedMinutes: parsed.estimatedMinutes,
                    scheduledStart: nil,
                    scheduledEnd: nil,
                    projectId: nil,
                    tags: nil,
                    aiReasoning: nil,
                    isAtRisk: false
                )
                state.tasks.insert(newTask, at: 0)
                state.naturalLanguageInput = ""
                let model = Self.makeModel(
                    id: taskId,
                    title: parsed.title,
                    deadline: parsed.deadline,
                    priority: parsed.priority,
                    energyLevel: parsed.energyLevel,
                    status: "inbox",
                    category: parsed.category,
                    estimatedMinutes: parsed.estimatedMinutes,
                    scheduledStart: nil,
                    scheduledEnd: nil,
                    projectId: nil,
                    tags: parsed.tags,
                    aiReasoning: nil
                )
                persistence.saveEATask(model)
                haptics.notificationSuccess()
                return .none

            case let .parsedPreviewLoaded(preview):
                state.parsedPreview = preview
                state.isAIParsing = false
                return .none

            case .confirmParsedTask:
                guard let preview = state.parsedPreview else { return .none }
                let taskId = UUID()
                let newTask = State.TaskState(
                    id: taskId,
                    title: preview.title,
                    deadline: preview.deadline,
                    priority: preview.priority,
                    energyLevel: preview.energyLevel,
                    status: "inbox",
                    category: preview.category,
                    estimatedMinutes: preview.estimatedMinutes,
                    scheduledStart: nil,
                    scheduledEnd: nil,
                    projectId: nil,
                    tags: nil,
                    aiReasoning: nil,
                    isAtRisk: false
                )
                state.tasks.insert(newTask, at: 0)
                state.parsedPreview = nil
                state.naturalLanguageInput = ""
                persistence.saveEATask(
                    Self.makeModel(
                        id: taskId,
                        title: preview.title,
                        deadline: preview.deadline,
                        priority: preview.priority,
                        energyLevel: preview.energyLevel,
                        status: "inbox",
                        category: preview.category,
                        estimatedMinutes: preview.estimatedMinutes,
                        scheduledStart: nil,
                        scheduledEnd: nil,
                        projectId: nil,
                        tags: nil,
                        aiReasoning: nil
                    )
                )
                haptics.notificationSuccess()
                return .none

            case .cancelParsedTask:
                state.parsedPreview = nil
                return .none

            case let .completeTask(id):
                if let index = state.tasks.firstIndex(where: { $0.id == id }) {
                    state.tasks[index].status = "completed"
                    let tasks = persistence.fetchEATasks()
                    if let model = tasks.first(where: { $0.uuid == id }) {
                        model.status = "completed"
                        persistence.updateEATasks()
                    }
                    haptics.notificationSuccess()
                }
                return .none

            case .rescheduleTask:
                return .none

            case let .deleteTask(id):
                state.tasks.removeAll { $0.id == id }
                persistence.deleteEATaskById(id)
                return .none

            case let .selectTask(id):
                state.selectedTaskId = id
                return .none

            case let .updateTaskStatus(id, status):
                if let index = state.tasks.firstIndex(where: { $0.id == id }) {
                    state.tasks[index].status = status
                    let tasks = persistence.fetchEATasks()
                    if let model = tasks.first(where: { $0.uuid == id }) {
                        model.status = status
                        persistence.updateEATasks()
                    }
                }
                return .none

            case .toggleSelectMode:
                state.isSelectMode.toggle()
                if !state.isSelectMode { state.selectedTaskIds.removeAll() }
                return .none

            case let .toggleTaskSelection(id):
                if state.selectedTaskIds.contains(id) {
                    state.selectedTaskIds.remove(id)
                } else {
                    state.selectedTaskIds.insert(id)
                }
                return .none

            case .batchComplete:
                for id in state.selectedTaskIds {
                    if let index = state.tasks.firstIndex(where: { $0.id == id }) {
                        state.tasks[index].status = "completed"
                        let tasks = persistence.fetchEATasks()
                        if let model = tasks.first(where: { $0.uuid == id }) {
                            model.status = "completed"
                            persistence.updateEATasks()
                        }
                    }
                }
                state.selectedTaskIds.removeAll()
                state.isSelectMode = false
                haptics.notificationSuccess()
                return .none

            case .batchDelete:
                for id in state.selectedTaskIds {
                    state.tasks.removeAll { $0.id == id }
                    persistence.deleteEATaskById(id)
                }
                state.selectedTaskIds.removeAll()
                state.isSelectMode = false
                haptics.notificationSuccess()
                return .none

            case .selectAll:
                state.selectedTaskIds = Set(state.filteredTasks.map(\.id))
                return .none

            case .deselectAll:
                state.selectedTaskIds.removeAll()
                return .none

            case .showAddTaskSheet:
                state.showAddTask = true
                state.newTaskTitle = ""
                state.newTaskPriority = "medium"
                state.newTaskCategory = "personal"
                state.newTaskDuration = 25
                return .none

            case .dismissAddTaskSheet:
                state.showAddTask = false
                return .none

            case let .newTaskTitleChanged(title):
                state.newTaskTitle = title
                return .none

            case let .newTaskPriorityChanged(priority):
                state.newTaskPriority = priority
                return .none

            case let .newTaskCategoryChanged(category):
                state.newTaskCategory = category
                return .none

            case let .newTaskDurationChanged(duration):
                state.newTaskDuration = duration
                return .none

            case .confirmNewTask:
                let title = state.newTaskTitle.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return .none }
                let taskId = UUID()
                let newTask = State.TaskState(
                    id: taskId,
                    title: title,
                    deadline: nil,
                    priority: state.newTaskPriority,
                    energyLevel: "lightWork",
                    status: "inbox",
                    category: state.newTaskCategory,
                    estimatedMinutes: state.newTaskDuration,
                    scheduledStart: nil,
                    scheduledEnd: nil,
                    projectId: nil,
                    tags: nil,
                    aiReasoning: nil,
                    isAtRisk: false
                )
                state.tasks.insert(newTask, at: 0)
                state.showAddTask = false
                persistence.saveEATask(
                    Self.makeModel(
                        id: taskId,
                        title: title,
                        deadline: nil,
                        priority: state.newTaskPriority,
                        energyLevel: "lightWork",
                        status: "inbox",
                        category: state.newTaskCategory,
                        estimatedMinutes: state.newTaskDuration,
                        scheduledStart: nil,
                        scheduledEnd: nil,
                        projectId: nil,
                        tags: nil,
                        aiReasoning: nil
                    )
                )
                haptics.notificationSuccess()
                return .none
            }
        }
    }
}

private extension EATaskReducer {
    static func taskState(from model: EATask) -> State.TaskState {
        State.TaskState(
            id: model.uuid,
            title: model.title,
            deadline: model.deadline,
            priority: model.priority,
            energyLevel: model.energyLevel,
            status: model.status,
            category: model.category,
            estimatedMinutes: model.estimatedMinutes,
            scheduledStart: model.scheduledStart,
            scheduledEnd: model.scheduledEnd,
            projectId: model.projectId,
            tags: model.tags,
            aiReasoning: model.aiReasoning,
            isAtRisk: model.isAtRisk
        )
    }

    static func inboxItemState(from model: EAInboxItem) -> State.InboxItemState {
        State.InboxItemState(
            id: model.uuid,
            rawInput: model.rawInput,
            classifiedType: model.classifiedType,
            confidence: model.confidence,
            isReviewed: model.isReviewed,
            createdAt: model.createdAt
        )
    }

    static func makeModel(
        id: UUID,
        title: String,
        deadline: Date?,
        priority: String,
        energyLevel: String,
        status: String,
        category: String,
        estimatedMinutes: Int?,
        scheduledStart: Date?,
        scheduledEnd: Date?,
        projectId: UUID?,
        tags: [String]?,
        aiReasoning: String?
    ) -> EATask {
        let model = EATask(
            title: title,
            deadline: deadline,
            priority: priority,
            energyLevel: energyLevel,
            status: status,
            category: category,
            estimatedMinutes: estimatedMinutes,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            projectId: projectId,
            tags: tags,
            aiReasoning: aiReasoning
        )
        model.uuid = id
        return model
    }
}
