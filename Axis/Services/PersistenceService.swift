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

    // MARK: - Meal Logs

    func fetchMealLogs() -> [MealLog] {
        let descriptor = FetchDescriptor<MealLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return fetchAll(MealLog.self, descriptor: descriptor, operation: "fetchMealLogs")
    }

    func saveMealLog(_ log: MealLog) {
        guard let context = modelContext else { return }
        context.insert(log)
        _ = saveContext("saveMealLog")
    }

    func updateMealLogs() {
        _ = saveContext("updateMealLogs")
    }

    func deleteMealLog(_ log: MealLog) {
        guard let context = modelContext else { return }
        context.delete(log)
        _ = saveContext("deleteMealLog")
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

    func deleteAllContacts() {
        guard let context = modelContext else { return }
        let contacts = fetchContacts()
        for contact in contacts {
            context.delete(contact)
        }
        _ = saveContext("deleteAllContacts")
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

    func deleteCapturedNote(_ note: CapturedNote) {
        guard let context = modelContext else { return }
        context.delete(note)
        _ = saveContext("deleteCapturedNote")
    }

    func updateCapturedNotes() {
        _ = saveContext("updateCapturedNotes")
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

    // MARK: - Chat Messages

    func fetchChatMessages(threadId: UUID? = nil) -> [ChatMessage] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.timestamp)])
        if let threadId {
            descriptor.predicate = #Predicate<ChatMessage> { $0.threadId == threadId }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveChatMessage(_ message: ChatMessage) {
        guard let context = modelContext else { return }
        context.insert(message)
        _ = saveContext("saveChatMessage")
    }

    func deleteChatMessage(_ id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? context.fetch(descriptor) {
            for msg in messages where msg.uuid == id {
                context.delete(msg)
            }
        }
        _ = saveContext("deleteChatMessage")
    }

    // MARK: - Chat Threads

    func fetchChatThreads() -> [ChatThread] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<ChatThread>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveChatThread(_ thread: ChatThread) {
        guard let context = modelContext else { return }
        context.insert(thread)
        _ = saveContext("saveChatThread")
    }

    func deleteChatThread(_ id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ChatThread>()
        if let threads = try? context.fetch(descriptor) {
            for thread in threads where thread.uuid == id {
                context.delete(thread)
            }
        }
        // Also delete messages
        let msgDescriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? context.fetch(msgDescriptor) {
            for msg in messages where msg.threadId == id {
                context.delete(msg)
            }
        }
        _ = saveContext("deleteChatThread")
    }

    func updateChatThreadTimestamp(_ id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ChatThread>()
        if let threads = try? context.fetch(descriptor) {
            for thread in threads where thread.uuid == id {
                thread.updatedAt = Date()
            }
        }
        _ = saveContext("updateChatThreadTimestamp")
    }

    // MARK: - Chore Counter

    func fetchChoreCounts() -> [ChoreCount] {
        let descriptor = FetchDescriptor<ChoreCount>()
        return fetchAll(ChoreCount.self, descriptor: descriptor, operation: "fetchChoreCounts")
    }

    func incrementChore(name: String, person: String) {
        guard let context = modelContext else { return }
        let all = fetchChoreCounts()
        let weekStart = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!)

        if let existing = all.first(where: { $0.choreName == name && $0.person == person && $0.weekStartDate == weekStart }) {
            existing.count += 1
        } else {
            let new = ChoreCount(choreName: name, person: person, count: 1)
            context.insert(new)
        }
        _ = saveContext("incrementChore")
    }

    func decrementChore(name: String, person: String) {
        let all = fetchChoreCounts()
        let weekStart = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!)
        if let existing = all.first(where: { $0.choreName == name && $0.person == person && $0.weekStartDate == weekStart }) {
            existing.count = max(0, existing.count - 1)
        }
        _ = saveContext("decrementChore")
    }

    func resetWeeklyChoreCounts() {
        guard let context = modelContext else { return }
        let all = fetchChoreCounts()
        for chore in all { context.delete(chore) }
        _ = saveContext("resetChoreCounts")
    }

    // MARK: - Bills

    func fetchBills(month: Int, year: Int) -> [BillEntry] {
        let descriptor = FetchDescriptor<BillEntry>()
        let all = fetchAll(BillEntry.self, descriptor: descriptor, operation: "fetchBills")
        return all.filter { $0.month == month && $0.year == year }
    }

    func saveBill(_ bill: BillEntry) {
        guard let context = modelContext else { return }
        context.insert(bill)
        _ = saveContext("saveBill")
    }

    func deleteBill(_ id: UUID) {
        guard let context = modelContext else { return }
        let all = fetchBills(month: 0, year: 0) // Fetch all, then filter
        let descriptor = FetchDescriptor<BillEntry>()
        let allBills = fetchAll(BillEntry.self, descriptor: descriptor, operation: "deleteBill")
        if let match = allBills.first(where: { $0.uuid == id }) {
            context.delete(match)
            _ = saveContext("deleteBill")
        }
    }

    func updateBills() {
        _ = saveContext("updateBills")
    }

    // MARK: - Voice Memos

    func fetchVoiceMemos() -> [VoiceMemo] {
        let descriptor = FetchDescriptor<VoiceMemo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(VoiceMemo.self, descriptor: descriptor, operation: "fetchVoiceMemos")
    }

    func saveVoiceMemo(_ memo: VoiceMemo) {
        guard let context = modelContext else { return }
        context.insert(memo)
        _ = saveContext("saveVoiceMemo")
    }

    func deleteVoiceMemo(_ memo: VoiceMemo) {
        guard let context = modelContext else { return }
        context.delete(memo)
        _ = saveContext("deleteVoiceMemo")
    }

    func updateVoiceMemos() {
        _ = saveContext("updateVoiceMemos")
    }

    // MARK: - Trips

    func fetchTrips() -> [Trip] {
        let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return fetchAll(Trip.self, descriptor: descriptor, operation: "fetchTrips")
    }

    func saveTrip(_ trip: Trip) {
        guard let context = modelContext else { return }
        context.insert(trip)
        _ = saveContext("saveTrip")
    }

    func deleteTrip(_ trip: Trip) {
        guard let context = modelContext else { return }
        context.delete(trip)
        _ = saveContext("deleteTrip")
    }

    func updateTrips() {
        _ = saveContext("updateTrips")
    }

    // MARK: - Itinerary Days

    func fetchItineraryDays(forTrip tripId: UUID) -> [ItineraryDay] {
        let descriptor = FetchDescriptor<ItineraryDay>(
            predicate: #Predicate { $0.tripId == tripId },
            sortBy: [SortDescriptor(\.dayNumber)]
        )
        return fetchAll(ItineraryDay.self, descriptor: descriptor, operation: "fetchItineraryDays")
    }

    func saveItineraryDay(_ day: ItineraryDay) {
        guard let context = modelContext else { return }
        context.insert(day)
        _ = saveContext("saveItineraryDay")
    }

    func deleteItineraryDay(_ day: ItineraryDay) {
        guard let context = modelContext else { return }
        context.delete(day)
        _ = saveContext("deleteItineraryDay")
    }

    // MARK: - Clipboard Items

    func fetchClipboardItems() -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetchAll(ClipboardItem.self, descriptor: descriptor, operation: "fetchClipboardItems")
    }

    func saveClipboardItem(_ item: ClipboardItem) {
        guard let context = modelContext else { return }
        context.insert(item)
        _ = saveContext("saveClipboardItem")
    }

    func deleteClipboardItem(_ item: ClipboardItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        _ = saveContext("deleteClipboardItem")
    }

    func updateClipboardItems() {
        _ = saveContext("updateClipboardItems")
    }

    // MARK: - Energy Check-Ins

    func fetchEnergyCheckIns(for date: Date) -> [EnergyCheckIn] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<EnergyCheckIn>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return fetchAll(EnergyCheckIn.self, descriptor: descriptor, operation: "fetchEnergyCheckIns")
    }

    func fetchEnergyCheckInsRange(start: Date, end: Date) -> [EnergyCheckIn] {
        let descriptor = FetchDescriptor<EnergyCheckIn>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return fetchAll(EnergyCheckIn.self, descriptor: descriptor, operation: "fetchEnergyCheckInsRange")
    }

    func saveEnergyCheckIn(_ checkIn: EnergyCheckIn) {
        guard let context = modelContext else { return }
        context.insert(checkIn)
        _ = saveContext("saveEnergyCheckIn")
    }

    // MARK: - Trip Expenses

    func fetchTripExpenses(tripId: UUID) -> [TripExpense] {
        let descriptor = FetchDescriptor<TripExpense>(
            predicate: #Predicate { $0.tripId == tripId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return fetchAll(TripExpense.self, descriptor: descriptor, operation: "fetchTripExpenses")
    }

    func saveTripExpense(_ expense: TripExpense) {
        guard let context = modelContext else { return }
        context.insert(expense)
        _ = saveContext("saveTripExpense")
    }

    func deleteTripExpense(_ expense: TripExpense) {
        guard let context = modelContext else { return }
        context.delete(expense)
        _ = saveContext("deleteTripExpense")
    }

    // MARK: - Trip Activities

    func fetchTripActivities(tripId: UUID) -> [TripActivity] {
        let descriptor = FetchDescriptor<TripActivity>(
            predicate: #Predicate { $0.tripId == tripId },
            sortBy: [SortDescriptor(\.dayNumber)]
        )
        return fetchAll(TripActivity.self, descriptor: descriptor, operation: "fetchTripActivities")
    }

    func saveTripActivity(_ activity: TripActivity) {
        guard let context = modelContext else { return }
        context.insert(activity)
        _ = saveContext("saveTripActivity")
    }

    func deleteTripActivity(_ activity: TripActivity) {
        guard let context = modelContext else { return }
        context.delete(activity)
        _ = saveContext("deleteTripActivity")
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
        fetchChoreCounts().forEach { context.delete($0) }
        if let profile = fetchUserProfile() {
            context.delete(profile)
        }

        return saveContext("resetAllData")
    }
}
