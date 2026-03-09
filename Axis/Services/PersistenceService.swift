import Foundation
import SwiftData

/// Central data access layer for SwiftData. Used by TCA reducers via dependency injection.
/// Note: Must be configured from main thread via configure(container:) at app launch.
final class PersistenceService: @unchecked Sendable {
    static let shared = PersistenceService()

    private var _context: ModelContext?
    var modelContext: ModelContext? { _context }

    private init() {}

    private func log(_ message: String) {
        #if DEBUG
        print("[PersistenceService] \(message)")
        #endif
    }

    @discardableResult
    private func saveContext(_ operation: String) -> Bool {
        guard let context = modelContext else {
            log("Skipped save (\(operation)): ModelContext not configured.")
            return false
        }
        do {
            try context.save()
            return true
        } catch {
            log("Save failed (\(operation)): \(error.localizedDescription)")
            return false
        }
    }

    private func fetchAll<T: PersistentModel>(
        _ type: T.Type,
        descriptor: FetchDescriptor<T>,
        operation: String
    ) -> [T] {
        guard let context = modelContext else {
            log("Fetch skipped (\(operation)): ModelContext not configured.")
            return []
        }
        do {
            return try context.fetch(descriptor)
        } catch {
            log("Fetch failed (\(operation)): \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    func configure(container: ModelContainer) {
        self._context = container.mainContext
    }

    // MARK: - Work Projects

    func fetchWorkProjects() -> [WorkProject] {
        let descriptor = FetchDescriptor<WorkProject>(sortBy: [SortDescriptor(\.sortOrder)])
        return fetchAll(WorkProject.self, descriptor: descriptor, operation: "fetchWorkProjects")
    }

    func saveWorkProject(_ project: WorkProject) {
        guard let context = modelContext else { return }
        context.insert(project)
        _ = saveContext("saveWorkProject")
    }

    func deleteWorkProject(_ project: WorkProject) {
        guard let context = modelContext else { return }
        context.delete(project)
        _ = saveContext("deleteWorkProject")
    }

    func updateWorkProjects() {
        _ = saveContext("updateWorkProjects")
    }

    // MARK: - Family Events

    func fetchFamilyEvents() -> [FamilyEvent] {
        let descriptor = FetchDescriptor<FamilyEvent>(sortBy: [SortDescriptor(\.date)])
        return fetchAll(FamilyEvent.self, descriptor: descriptor, operation: "fetchFamilyEvents")
    }

    func saveFamilyEvent(_ event: FamilyEvent) {
        guard let context = modelContext else { return }
        context.insert(event)
        _ = saveContext("saveFamilyEvent")
    }

    func deleteFamilyEvent(_ event: FamilyEvent) {
        guard let context = modelContext else { return }
        context.delete(event)
        _ = saveContext("deleteFamilyEvent")
    }

    func updateFamilyEvents() {
        _ = saveContext("updateFamilyEvents")
    }

    // MARK: - Meal Plans

    func fetchMealPlans() -> [MealPlan] {
        let descriptor = FetchDescriptor<MealPlan>(sortBy: [SortDescriptor(\.dayOfWeek)])
        return fetchAll(MealPlan.self, descriptor: descriptor, operation: "fetchMealPlans")
    }

    func saveMealPlan(_ plan: MealPlan) {
        guard let context = modelContext else { return }
        context.insert(plan)
        _ = saveContext("saveMealPlan")
    }

    func updateMealPlans() {
        _ = saveContext("updateMealPlans")
    }

    func deleteAllMealPlans() {
        guard let context = modelContext else { return }
        let plans = fetchMealPlans()
        for plan in plans { context.delete(plan) }
        _ = saveContext("deleteAllMealPlans")
    }

    // MARK: - Dad Wins

    func fetchDadWins() -> [DadWin] {
        let descriptor = FetchDescriptor<DadWin>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return fetchAll(DadWin.self, descriptor: descriptor, operation: "fetchDadWins")
    }

    func saveDadWin(_ win: DadWin) {
        guard let context = modelContext else { return }
        context.insert(win)
        _ = saveContext("saveDadWin")
    }

    func deleteDadWin(_ win: DadWin) {
        guard let context = modelContext else { return }
        context.delete(win)
        _ = saveContext("deleteDadWin")
    }

    // MARK: - Goals

    func fetchGoals() -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(Goal.self, descriptor: descriptor, operation: "fetchGoals")
    }

    func saveGoal(_ goal: Goal) {
        guard let context = modelContext else { return }
        context.insert(goal)
        _ = saveContext("saveGoal")
    }

    func deleteGoal(_ goal: Goal) {
        guard let context = modelContext else { return }
        context.delete(goal)
        _ = saveContext("deleteGoal")
    }

    func updateGoals() {
        _ = saveContext("updateGoals")
    }

    // MARK: - Focus Sessions

    func fetchFocusSessions() -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return fetchAll(FocusSession.self, descriptor: descriptor, operation: "fetchFocusSessions")
    }

    func saveFocusSession(_ session: FocusSession) {
        guard let context = modelContext else { return }
        context.insert(session)
        _ = saveContext("saveFocusSession")
    }

    // MARK: - Contacts

    func fetchContacts() -> [Contact] {
        let descriptor = FetchDescriptor<Contact>(sortBy: [SortDescriptor(\.name)])
        return fetchAll(Contact.self, descriptor: descriptor, operation: "fetchContacts")
    }

    func saveContact(_ contact: Contact) {
        guard let context = modelContext else { return }
        context.insert(contact)
        _ = saveContext("saveContact")
    }

    func deleteContact(_ contact: Contact) {
        guard let context = modelContext else { return }
        context.delete(contact)
        _ = saveContext("deleteContact")
    }

    func updateContacts() {
        _ = saveContext("updateContacts")
    }

    // MARK: - Saved Places

    func fetchSavedPlaces() -> [SavedPlace] {
        let descriptor = FetchDescriptor<SavedPlace>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(SavedPlace.self, descriptor: descriptor, operation: "fetchSavedPlaces")
    }

    func saveSavedPlace(_ place: SavedPlace) {
        guard let context = modelContext else { return }
        context.insert(place)
        _ = saveContext("saveSavedPlace")
    }

    func deleteSavedPlace(_ place: SavedPlace) {
        guard let context = modelContext else { return }
        context.delete(place)
        _ = saveContext("deleteSavedPlace")
    }

    func updateSavedPlaces() {
        _ = saveContext("updateSavedPlaces")
    }

    func deleteAllSavedPlaces() {
        guard let context = modelContext else { return }
        let places = fetchSavedPlaces()
        for place in places { context.delete(place) }
        _ = saveContext("deleteAllSavedPlaces")
    }

    // MARK: - Captured Notes

    func fetchCapturedNotes() -> [CapturedNote] {
        let descriptor = FetchDescriptor<CapturedNote>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(CapturedNote.self, descriptor: descriptor, operation: "fetchCapturedNotes")
    }

    func saveCapturedNote(_ note: CapturedNote) {
        guard let context = modelContext else { return }
        context.insert(note)
        _ = saveContext("saveCapturedNote")
    }

    // MARK: - Priority Items

    func fetchPriorityItems() -> [PriorityItem] {
        let descriptor = FetchDescriptor<PriorityItem>(sortBy: [SortDescriptor(\.sortOrder)])
        return fetchAll(PriorityItem.self, descriptor: descriptor, operation: "fetchPriorityItems")
    }

    func savePriorityItem(_ item: PriorityItem) {
        guard let context = modelContext else { return }
        context.insert(item)
        _ = saveContext("savePriorityItem")
    }

    func deletePriorityItem(_ item: PriorityItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        _ = saveContext("deletePriorityItem")
    }

    func updatePriorityItems() {
        _ = saveContext("updatePriorityItems")
    }

    // MARK: - User Profile

    func fetchUserProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return fetchAll(UserProfile.self, descriptor: descriptor, operation: "fetchUserProfile").first
    }

    func saveUserProfile(_ profile: UserProfile) {
        guard let context = modelContext else { return }
        context.insert(profile)
        _ = saveContext("saveUserProfile")
    }

    func updateUserProfile() {
        _ = saveContext("updateUserProfile")
    }

    func getOrCreateProfile() -> UserProfile {
        if let existing = fetchUserProfile() {
            return existing
        }
        let profile = UserProfile()
        saveUserProfile(profile)
        return profile
    }

    // MARK: - Interactions

    func fetchInteractions(forContact contactId: UUID) -> [Interaction] {
        let descriptor = FetchDescriptor<Interaction>(
            predicate: #Predicate { $0.contactId == contactId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return fetchAll(Interaction.self, descriptor: descriptor, operation: "fetchInteractions")
    }

    func fetchAllInteractions() -> [Interaction] {
        let descriptor = FetchDescriptor<Interaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return fetchAll(Interaction.self, descriptor: descriptor, operation: "fetchAllInteractions")
    }

    func saveInteraction(_ interaction: Interaction) {
        guard let context = modelContext else { return }
        context.insert(interaction)
        _ = saveContext("saveInteraction")
    }

    func deleteInteraction(_ interaction: Interaction) {
        guard let context = modelContext else { return }
        context.delete(interaction)
        _ = saveContext("deleteInteraction")
    }

    // MARK: - Contact Groups

    func fetchContactGroups() -> [ContactGroup] {
        let descriptor = FetchDescriptor<ContactGroup>(sortBy: [SortDescriptor(\.name)])
        return fetchAll(ContactGroup.self, descriptor: descriptor, operation: "fetchContactGroups")
    }

    func saveContactGroup(_ group: ContactGroup) {
        guard let context = modelContext else { return }
        context.insert(group)
        _ = saveContext("saveContactGroup")
    }

    func deleteContactGroup(_ group: ContactGroup) {
        guard let context = modelContext else { return }
        context.delete(group)
        _ = saveContext("deleteContactGroup")
    }

    func updateContactGroups() {
        _ = saveContext("updateContactGroups")
    }

    // MARK: - Subtasks

    func fetchSubtasks(forProject projectId: UUID) -> [Subtask] {
        let descriptor = FetchDescriptor<Subtask>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return fetchAll(Subtask.self, descriptor: descriptor, operation: "fetchSubtasks")
    }

    func saveSubtask(_ subtask: Subtask) {
        guard let context = modelContext else { return }
        context.insert(subtask)
        _ = saveContext("saveSubtask")
    }

    func deleteSubtask(_ subtask: Subtask) {
        guard let context = modelContext else { return }
        context.delete(subtask)
        _ = saveContext("deleteSubtask")
    }

    func updateSubtasks() {
        _ = saveContext("updateSubtasks")
    }

    // MARK: - Focus Profiles

    func fetchFocusProfiles() -> [FocusProfile] {
        let descriptor = FetchDescriptor<FocusProfile>(sortBy: [SortDescriptor(\FocusProfile.createdAt)])
        return fetchAll(FocusProfile.self, descriptor: descriptor, operation: "fetchFocusProfiles")
    }

    func saveFocusProfile(_ profile: FocusProfile) {
        guard let context = modelContext else { return }
        context.insert(profile)
        _ = saveContext("saveFocusProfile")
    }

    func deleteFocusProfile(_ profile: FocusProfile) {
        guard let context = modelContext else { return }
        context.delete(profile)
        _ = saveContext("deleteFocusProfile")
    }

    func updateFocusProfiles() {
        _ = saveContext("updateFocusProfiles")
    }

    // MARK: - EA Tasks

    func fetchEATasks() -> [EATask] {
        let descriptor = FetchDescriptor<EATask>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(EATask.self, descriptor: descriptor, operation: "fetchEATasks")
    }

    func fetchEATasksByProject(projectId: UUID) -> [EATask] {
        let descriptor = FetchDescriptor<EATask>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return fetchAll(EATask.self, descriptor: descriptor, operation: "fetchEATasksByProject")
    }

    func saveEATask(_ task: EATask) {
        guard let context = modelContext else { return }
        context.insert(task)
        _ = saveContext("saveEATask")
    }

    func deleteEATask(_ task: EATask) {
        guard let context = modelContext else { return }
        context.delete(task)
        _ = saveContext("deleteEATask")
    }

    func updateEATasks() {
        _ = saveContext("updateEATasks")
    }

    // MARK: - EA Projects

    func fetchEAProjects() -> [EAProject] {
        let descriptor = FetchDescriptor<EAProject>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(EAProject.self, descriptor: descriptor, operation: "fetchEAProjects")
    }

    func saveEAProject(_ project: EAProject) {
        guard let context = modelContext else { return }
        context.insert(project)
        _ = saveContext("saveEAProject")
    }

    func deleteEAProject(_ project: EAProject) {
        guard let context = modelContext else { return }
        context.delete(project)
        _ = saveContext("deleteEAProject")
    }

    func updateEAProjects() {
        _ = saveContext("updateEAProjects")
    }

    // MARK: - EA Milestones

    func fetchEAMilestones(forProject projectId: UUID) -> [EAMilestone] {
        let descriptor = FetchDescriptor<EAMilestone>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return fetchAll(EAMilestone.self, descriptor: descriptor, operation: "fetchEAMilestones")
    }

    func saveEAMilestone(_ milestone: EAMilestone) {
        guard let context = modelContext else { return }
        context.insert(milestone)
        _ = saveContext("saveEAMilestone")
    }

    func deleteEAMilestone(_ milestone: EAMilestone) {
        guard let context = modelContext else { return }
        context.delete(milestone)
        _ = saveContext("deleteEAMilestone")
    }

    func updateEAMilestones() {
        _ = saveContext("updateEAMilestones")
    }

    // MARK: - EA Daily Plans

    func fetchEADailyPlan(for date: Date) -> EADailyPlan? {
        let descriptor = FetchDescriptor<EADailyPlan>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        return fetchAll(EADailyPlan.self, descriptor: descriptor, operation: "fetchEADailyPlan")
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func saveEADailyPlan(_ plan: EADailyPlan) {
        guard let context = modelContext else { return }
        context.insert(plan)
        _ = saveContext("saveEADailyPlan")
    }

    func deleteEADailyPlan(_ plan: EADailyPlan) {
        guard let context = modelContext else { return }
        context.delete(plan)
        _ = saveContext("deleteEADailyPlan")
    }

    // MARK: - EA Time Blocks

    func fetchEATimeBlocks(forPlan planId: UUID) -> [EATimeBlock] {
        let descriptor = FetchDescriptor<EATimeBlock>(
            predicate: #Predicate { $0.planId == planId },
            sortBy: [SortDescriptor(\.startTime)]
        )
        return fetchAll(EATimeBlock.self, descriptor: descriptor, operation: "fetchEATimeBlocks")
    }

    func saveEATimeBlock(_ timeBlock: EATimeBlock) {
        guard let context = modelContext else { return }
        context.insert(timeBlock)
        _ = saveContext("saveEATimeBlock")
    }

    func deleteEATimeBlock(_ timeBlock: EATimeBlock) {
        guard let context = modelContext else { return }
        context.delete(timeBlock)
        _ = saveContext("deleteEATimeBlock")
    }

    // MARK: - EA Inbox Items

    func fetchEAInboxItems() -> [EAInboxItem] {
        let descriptor = FetchDescriptor<EAInboxItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(EAInboxItem.self, descriptor: descriptor, operation: "fetchEAInboxItems")
    }

    func fetchUnreviewedEAInboxItems() -> [EAInboxItem] {
        let descriptor = FetchDescriptor<EAInboxItem>(
            predicate: #Predicate { $0.isReviewed == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return fetchAll(EAInboxItem.self, descriptor: descriptor, operation: "fetchUnreviewedEAInboxItems")
    }

    func saveEAInboxItem(_ inboxItem: EAInboxItem) {
        guard let context = modelContext else { return }
        context.insert(inboxItem)
        _ = saveContext("saveEAInboxItem")
    }

    func deleteEAInboxItem(_ inboxItem: EAInboxItem) {
        guard let context = modelContext else { return }
        context.delete(inboxItem)
        _ = saveContext("deleteEAInboxItem")
    }

    func updateEAInboxItems() {
        _ = saveContext("updateEAInboxItems")
    }

    // MARK: - QA Utilities

    /// Debug utility for local QA resets. Removes all persisted records.
    /// Returns `true` when save succeeds after deletes.
    @discardableResult
    func resetAllData() -> Bool {
        guard let context = modelContext else {
            log("Reset skipped: ModelContext not configured.")
            return false
        }

        fetchWorkProjects().forEach { context.delete($0) }
        fetchFamilyEvents().forEach { context.delete($0) }
        fetchMealPlans().forEach { context.delete($0) }
        fetchDadWins().forEach { context.delete($0) }
        fetchGoals().forEach { context.delete($0) }
        fetchContacts().forEach { context.delete($0) }
        fetchSavedPlaces().forEach { context.delete($0) }
        fetchCapturedNotes().forEach { context.delete($0) }
        fetchPriorityItems().forEach { context.delete($0) }
        fetchFocusSessions().forEach { context.delete($0) }
        fetchEATasks().forEach { context.delete($0) }
        fetchEAProjects().forEach { context.delete($0) }
        let milestoneDescriptor = FetchDescriptor<EAMilestone>()
        fetchAll(EAMilestone.self, descriptor: milestoneDescriptor, operation: "resetAllData.fetchEAMilestones").forEach { context.delete($0) }
        let dailyPlanDescriptor = FetchDescriptor<EADailyPlan>()
        fetchAll(EADailyPlan.self, descriptor: dailyPlanDescriptor, operation: "resetAllData.fetchEADailyPlans").forEach { context.delete($0) }
        let timeBlockDescriptor = FetchDescriptor<EATimeBlock>()
        fetchAll(EATimeBlock.self, descriptor: timeBlockDescriptor, operation: "resetAllData.fetchEATimeBlocks").forEach { context.delete($0) }
        fetchEAInboxItems().forEach { context.delete($0) }
        if let profile = fetchUserProfile() {
            context.delete(profile)
        }

        return saveContext("resetAllData")
    }
}
