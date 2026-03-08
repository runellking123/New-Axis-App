import AppIntents
import Foundation

// MARK: - Add Priority Intent

struct AddPriorityIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Priority"
    static var description = IntentDescription("Add a new priority to your AXIS command center.")
    static var openAppWhenRun = false

    @Parameter(title: "Title")
    var priorityTitle: String

    @Parameter(title: "Category", default: "commandCenter")
    var category: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceService.shared
        let existingCount = persistence.fetchPriorityItems().count
        let item = PriorityItem(
            title: priorityTitle,
            sourceModule: category,
            sortOrder: existingCount
        )
        persistence.savePriorityItem(item)
        return .result(dialog: "Added '\(priorityTitle)' to your priorities.")
    }
}

// MARK: - Add Goal Intent

struct AddGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Goal"
    static var description = IntentDescription("Create a new goal with milestones.")
    static var openAppWhenRun = false

    @Parameter(title: "Goal Title")
    var goalTitle: String

    @Parameter(title: "Category", default: "personal")
    var category: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let goal = Goal(title: goalTitle, category: category)
        PersistenceService.shared.saveGoal(goal)
        return .result(dialog: "Goal created: '\(goalTitle)'. Add milestones in the app!")
    }
}

// MARK: - Quick Capture Intent

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Capture"
    static var description = IntentDescription("Capture a quick thought to AXIS.")
    static var openAppWhenRun = false

    @Parameter(title: "Note")
    var noteContent: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let note = CapturedNote(content: noteContent, classifiedModule: "commandCenter")
        PersistenceService.shared.saveCapturedNote(note)

        let existingCount = PersistenceService.shared.fetchPriorityItems().count
        let item = PriorityItem(title: noteContent, sortOrder: existingCount)
        PersistenceService.shared.savePriorityItem(item)

        return .result(dialog: "Captured: '\(noteContent)'")
    }
}

// MARK: - Check Priorities Intent

struct CheckPrioritiesIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Priorities"
    static var description = IntentDescription("See how many priorities you have remaining.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = PersistenceService.shared.fetchPriorityItems()
        let remaining = items.filter { !$0.isCompleted }.count
        let total = items.count

        if remaining == 0 && total > 0 {
            return .result(dialog: "All \(total) priorities are done! You're crushing it.")
        } else if remaining == 0 {
            return .result(dialog: "No priorities set. Add some with 'Add Priority'.")
        } else {
            return .result(dialog: "You have \(remaining) of \(total) priorities remaining today.")
        }
    }
}

// MARK: - App Shortcuts Provider

struct AxisAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPriorityIntent(),
            phrases: [
                "Add a priority in \(.applicationName)",
                "Add to my \(.applicationName) priorities"
            ],
            shortTitle: "Add Priority",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: AddGoalIntent(),
            phrases: [
                "Add a goal in \(.applicationName)",
                "Create a goal with \(.applicationName)"
            ],
            shortTitle: "Add Goal",
            systemImageName: "target"
        )
        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Quick capture in \(.applicationName)",
                "Capture a thought with \(.applicationName)"
            ],
            shortTitle: "Quick Capture",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: CheckPrioritiesIntent(),
            phrases: [
                "Check my priorities in \(.applicationName)",
                "How many priorities in \(.applicationName)"
            ],
            shortTitle: "Check Priorities",
            systemImageName: "checklist"
        )
    }
}
