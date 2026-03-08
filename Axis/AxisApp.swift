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
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        PersistenceService.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(initialState: AppReducer.State()) {
                    AppReducer()
                }
            )
        }
        .modelContainer(container)
    }
}
