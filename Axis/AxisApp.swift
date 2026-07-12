import SwiftUI
import SwiftData
import ComposableArchitecture
#if DEBUG
import Inject   // InjectionNext hot-reload runtime hook (DEBUG only)
#endif

@main
struct AxisApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            PriorityItem.self,
            CapturedNote.self,
            WidgetLayoutConfig.self,
            WorkProject.self,
            FamilyEvent.self,
            MealPlan.self,
            MealLog.self,
            DadWin.self,
            Goal.self,
            Milestone.self,
            Contact.self,
            SavedPlace.self,
            FocusSession.self,
            // Phase 1
            Subtask.self,
            FocusProfile.self,
            // Phase 2
            Interaction.self,
            ContactGroup.self,
            // Phase 3
            FamilyMember.self,
            Chore.self,
            ShoppingList.self,
            ShoppingItem.self,
            Recipe.self,
            BucketListGoal.self,
            // Phase 4
            MoodEntry.self,
            WaterEntry.self,
            JournalEntry.self,
            Routine.self,
            RoutineStep.self,
            RoutineCompletion.self,
            // Phase 5
            Trip.self,
            ItineraryDay.self,
            PlacePhoto.self,
            // Phase 6
            Habit.self,
            HabitCompletion.self,
            // Phase 7
            TrendSnapshot.self,
            // M6: EA Models
            EATask.self,
            EAProject.self,
            EAMilestone.self,
            EADailyPlan.self,
            EATimeBlock.self,
            EAInboxItem.self,
            // M6: Chat Models
            ChatMessage.self,
            ChatThread.self,
            // Chore Counter
            ChoreCount.self,
            // Budget & Bills
            BillEntry.self,
            // Voice Memos
            VoiceMemo.self,
            // Clipboard
            ClipboardItem.self,
            // Energy Check-ins
            EnergyCheckIn.self,
            // Travel Expenses & Activities
            TripExpense.self,
            TripActivity.self,
        ])
        // CloudKit mirroring requires a valid iCloud container entitlement. Unsigned
        // simulator builds don't have that, which makes CoreData's CloudKit setup
        // assert inside PFCloudKitContainerProvider at launch. Skip CloudKit for
        // simulator builds — real-device/signed builds still sync normally.
        #if targetEnvironment(simulator)
        let config = ModelConfiguration(schema: schema)
        #else
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.runellking.axis")
        )
        #endif
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        PersistenceService.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacAppView(
                store: Store(initialState: AppReducer.State()) {
                    AppReducer()
                }
            )
            .hotReloadRoot()
            #else
            AppView(
                store: Store(initialState: AppReducer.State()) {
                    AppReducer()
                }
            )
            .hotReloadRoot()
            #endif
        }
        .modelContainer(container)
    }
}

// MARK: - Hot Reload (InjectionNext)

extension View {
    /// Rebuilds the entire view tree every time InjectionNext hot-swaps source,
    /// so EVERY screen reflects code edits live — no per-view `@ObserveInjection`
    /// wiring required. Applied once, at the app root. No-op in release builds.
    func hotReloadRoot() -> some View {
        #if DEBUG
        InjectionRoot { self }
        #else
        self
        #endif
    }
}

#if DEBUG
/// Observes InjectionNext's shared injection counter and keys the wrapped content
/// on it via `.id(...)`. When you save a file, InjectionNext recompiles + rebinds
/// the symbol and bumps `injectionNumber`; the `.id` change forces SwiftUI to
/// discard and rebuild the whole tree, so the swapped code is what gets rendered.
private struct InjectionRoot<Content: View>: View {
    @ObservedObject private var observer = InjectConfiguration.observer
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().id(observer.injectionNumber)
    }
}
#endif
