import SwiftUI
import SwiftData
import ComposableArchitecture

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
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.runellking.axis")
        )
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
            #else
            AppView(
                store: Store(initialState: AppReducer.State()) {
                    AppReducer()
                }
            )
            #endif
        }
        .modelContainer(container)
    }
}
