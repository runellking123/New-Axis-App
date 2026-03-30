import SwiftUI
import WidgetKit

@main
struct AxisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrioritiesWidget()
        EnergyWidget()
        QuickActionsWidget()
        DeadlinesWidget()
        TodayScheduleWidget()
    }
}
