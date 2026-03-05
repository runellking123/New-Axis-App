import Foundation
import SwiftData

/// Central data access layer for SwiftData. Used by TCA reducers via dependency injection.
/// Note: Must be configured from main thread via configure(container:) at app launch.
final class PersistenceService: @unchecked Sendable {
    static let shared = PersistenceService()

    private var _context: ModelContext?
    var modelContext: ModelContext? { _context }

    private init() {}

    @MainActor
    func configure(container: ModelContainer) {
        self._context = container.mainContext
    }

    // MARK: - Work Projects

    func fetchWorkProjects() -> [WorkProject] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WorkProject>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveWorkProject(_ project: WorkProject) {
        guard let context = modelContext else { return }
        context.insert(project)
        try? context.save()
    }

    func deleteWorkProject(_ project: WorkProject) {
        guard let context = modelContext else { return }
        context.delete(project)
        try? context.save()
    }

    func updateWorkProjects() {
        try? modelContext?.save()
    }

    // MARK: - Family Events

    func fetchFamilyEvents() -> [FamilyEvent] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FamilyEvent>(sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveFamilyEvent(_ event: FamilyEvent) {
        guard let context = modelContext else { return }
        context.insert(event)
        try? context.save()
    }

    func deleteFamilyEvent(_ event: FamilyEvent) {
        guard let context = modelContext else { return }
        context.delete(event)
        try? context.save()
    }

    func updateFamilyEvents() {
        try? modelContext?.save()
    }

    // MARK: - Meal Plans

    func fetchMealPlans() -> [MealPlan] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<MealPlan>(sortBy: [SortDescriptor(\.dayOfWeek)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveMealPlan(_ plan: MealPlan) {
        guard let context = modelContext else { return }
        context.insert(plan)
        try? context.save()
    }

    func updateMealPlans() {
        try? modelContext?.save()
    }

    func deleteAllMealPlans() {
        guard let context = modelContext else { return }
        let plans = fetchMealPlans()
        for plan in plans { context.delete(plan) }
        try? context.save()
    }

    // MARK: - Dad Wins

    func fetchDadWins() -> [DadWin] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<DadWin>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveDadWin(_ win: DadWin) {
        guard let context = modelContext else { return }
        context.insert(win)
        try? context.save()
    }

    func deleteDadWin(_ win: DadWin) {
        guard let context = modelContext else { return }
        context.delete(win)
        try? context.save()
    }

    // MARK: - Contacts

    func fetchContacts() -> [Contact] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Contact>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveContact(_ contact: Contact) {
        guard let context = modelContext else { return }
        context.insert(contact)
        try? context.save()
    }

    func deleteContact(_ contact: Contact) {
        guard let context = modelContext else { return }
        context.delete(contact)
        try? context.save()
    }

    func updateContacts() {
        try? modelContext?.save()
    }

    // MARK: - Saved Places

    func fetchSavedPlaces() -> [SavedPlace] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedPlace>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveSavedPlace(_ place: SavedPlace) {
        guard let context = modelContext else { return }
        context.insert(place)
        try? context.save()
    }

    func deleteSavedPlace(_ place: SavedPlace) {
        guard let context = modelContext else { return }
        context.delete(place)
        try? context.save()
    }

    func updateSavedPlaces() {
        try? modelContext?.save()
    }

    // MARK: - Captured Notes

    func fetchCapturedNotes() -> [CapturedNote] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<CapturedNote>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveCapturedNote(_ note: CapturedNote) {
        guard let context = modelContext else { return }
        context.insert(note)
        try? context.save()
    }

    // MARK: - Priority Items

    func fetchPriorityItems() -> [PriorityItem] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<PriorityItem>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func savePriorityItem(_ item: PriorityItem) {
        guard let context = modelContext else { return }
        context.insert(item)
        try? context.save()
    }

    func deletePriorityItem(_ item: PriorityItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        try? context.save()
    }

    func updatePriorityItems() {
        try? modelContext?.save()
    }

    // MARK: - User Profile

    func fetchUserProfile() -> UserProfile? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<UserProfile>()
        return (try? context.fetch(descriptor))?.first
    }

    func saveUserProfile(_ profile: UserProfile) {
        guard let context = modelContext else { return }
        context.insert(profile)
        try? context.save()
    }

    func updateUserProfile() {
        try? modelContext?.save()
    }

    func getOrCreateProfile() -> UserProfile {
        if let existing = fetchUserProfile() {
            return existing
        }
        let profile = UserProfile()
        saveUserProfile(profile)
        return profile
    }
}
