import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct AxisApp: App {
    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(initialState: AppReducer.State()) {
                    AppReducer()
                }
            )
        }
        .modelContainer(for: [
            UserProfile.self,
            PriorityItem.self,
            CapturedNote.self,
            WidgetLayoutConfig.self
        ])
    }
}
