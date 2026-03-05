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
            Contact.self,
            SavedPlace.self
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
