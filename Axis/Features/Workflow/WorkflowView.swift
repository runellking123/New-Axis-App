import ComposableArchitecture
import SwiftUI

struct WorkflowView: View {
    let tasksStore: StoreOf<EATaskReducer>
    let plannerStore: StoreOf<EAPlannerReducer>
    let projectsStore: StoreOf<EAProjectReducer>

    @State private var selectedSection: Section = .tasks

    enum Section: String, CaseIterable {
        case tasks = "Tasks"
        case timeline = "Timeline"
        case projects = "Projects"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("Section", selection: $selectedSection) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Content
            switch selectedSection {
            case .tasks:
                EATaskListView(store: tasksStore)
            case .timeline:
                EAPlannerView(store: plannerStore)
            case .projects:
                EAProjectListView(store: projectsStore)
            }
        }
    }
}
