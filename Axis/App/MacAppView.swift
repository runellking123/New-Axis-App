import SwiftUI
import ComposableArchitecture

#if os(macOS)
struct MacAppView: View {
    @Bindable var store: StoreOf<AppReducer>
    @State private var searchText = ""

    var body: some View {
        if store.showOnboarding {
            OnboardingView {
                store.send(.completeOnboarding)
            }
            .frame(minWidth: 600, minHeight: 400)
        } else {
            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .frame(minWidth: 1000, minHeight: 700)
            .onAppear { store.send(.onAppear) }
            .onOpenURL { url in store.send(.handleDeepLink(url)) }
        }
    }

    // MARK: - Sidebar

    private var allItems: [SidebarItem] {
        primaryItems + productivityItems + lifeItems + toolItems
    }

    private var filteredSections: [(String, [SidebarItem])] {
        let query = searchText.lowercased()
        let sections: [(String, [SidebarItem])] = [
            ("Main", primaryItems),
            ("Productivity", productivityItems),
            ("Life", lifeItems),
            ("Tools", toolItems),
        ]
        if query.isEmpty { return sections }
        return sections.compactMap { name, items in
            let filtered = items.filter { $0.title.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (name, filtered)
        }
    }

    private var sidebarContent: some View {
        List(selection: Binding(
            get: { store.selectedTab },
            set: { tab in
                if let tab { store.send(.tabSelected(tab)) }
            }
        )) {
            ForEach(filteredSections, id: \.0) { name, items in
                Section(name) {
                    ForEach(items, id: \.tab) { item in
                        sidebarRow(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search tabs...")
        .navigationTitle("AXIS")
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.icon)
            .tag(item.tab)
    }

    // MARK: - Sidebar Items

    private struct SidebarItem {
        let tab: AppReducer.State.Tab
        let title: String
        let icon: String
    }

    private let primaryItems: [SidebarItem] = [
        SidebarItem(tab: .dashboard, title: "Dashboard", icon: "brain.head.profile.fill"),
        SidebarItem(tab: .calendar, title: "Calendar", icon: "calendar"),
        SidebarItem(tab: .aiChat, title: "AI Chat", icon: "bubble.left.and.text.bubble.right"),
    ]

    private let productivityItems: [SidebarItem] = [
        SidebarItem(tab: .tasks, title: "Workflow", icon: "rectangle.stack.fill"),
        SidebarItem(tab: .notes, title: "Notes", icon: "note.text"),
        SidebarItem(tab: .voiceMemos, title: "Voice Memos", icon: "mic.fill"),
        SidebarItem(tab: .clipboard, title: "Clipboard", icon: "doc.on.clipboard"),
    ]

    private let lifeItems: [SidebarItem] = [
        SidebarItem(tab: .budget, title: "Budget", icon: "dollarsign.circle.fill"),
        SidebarItem(tab: .social, title: "Social", icon: "person.2.fill"),
        SidebarItem(tab: .familyHQ, title: "FamilyHQ", icon: "house.and.flag.fill"),
        SidebarItem(tab: .balance, title: "Balance", icon: "heart.circle.fill"),
        SidebarItem(tab: .explore, title: "Explore", icon: "map.fill"),
        SidebarItem(tab: .travel, title: "Travel", icon: "airplane"),
    ]

    private let toolItems: [SidebarItem] = [
        SidebarItem(tab: .trends, title: "News", icon: "newspaper.fill"),
        SidebarItem(tab: .settings, title: "Settings", icon: "gearshape.fill"),
    ]

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch store.selectedTab {
        case .dashboard:
            EADashboardView(
                store: store.scope(state: \.eaDashboard, action: \.eaDashboard),
                onNavigateToPlanner: { store.send(.tabSelected(.tasks)) },
                onNavigateToTasks: { store.send(.tabSelected(.tasks)) },
                onNavigateToProjects: { store.send(.tabSelected(.tasks)) },
                onSettingsTapped: { store.send(.toggleSettings) },
                onAddTapped: {
                    store.send(.tabSelected(.tasks))
                    store.send(.eaTasks(.showAddTaskSheet))
                },
                onCompletedTasksTapped: {
                    store.send(.tabSelected(.tasks))
                    store.send(.eaTasks(.filterChanged(.done)))
                },
                onMeetingsTapped: { store.send(.tabSelected(.tasks)) },
                onDeepWorkTapped: { store.send(.tabSelected(.tasks)) },
                onToggleDarkMode: {
                    let current = store.settings.darkModeOverride
                    let next: SettingsReducer.State.DarkModeOption = current == .dark ? .light : .dark
                    store.send(.settings(.darkModeChanged(next)))
                },
                isDarkMode: store.settings.darkModeOverride == .dark
            )
        case .calendar:
            CalendarTabView()
        case .voiceMemos:
            VoiceMemosView(store: store.scope(state: \.voiceMemos, action: \.voiceMemos))
        case .aiChat:
            AIChatView(store: store.scope(state: \.aiChat, action: \.aiChat))
        case .notes:
            QuickNotesView(store: store.scope(state: \.quickNotes, action: \.quickNotes))
        case .tasks:
            WorkflowView(
                tasksStore: store.scope(state: \.eaTasks, action: \.eaTasks),
                plannerStore: store.scope(state: \.eaPlanner, action: \.eaPlanner),
                projectsStore: store.scope(state: \.eaProjects, action: \.eaProjects)
            )
        case .explore:
            ExploreView(store: store.scope(state: \.explore, action: \.explore))
        case .planner:
            EAPlannerView(store: store.scope(state: \.eaPlanner, action: \.eaPlanner))
        case .projects:
            EAProjectListView(store: store.scope(state: \.eaProjects, action: \.eaProjects))
        case .social:
            SocialCircleView(store: store.scope(state: \.socialCircle, action: \.socialCircle))
        case .familyHQ:
            FamilyHQView(store: store.scope(state: \.familyHQ, action: \.familyHQ))
        case .balance:
            BalanceView(store: store.scope(state: \.balance, action: \.balance))
        case .budget:
            BudgetView(store: store.scope(state: \.budget, action: \.budget))
        case .trends:
            TrendsView(store: store.scope(state: \.trends, action: \.trends))
        case .travel:
            TravelPlannerView(store: store.scope(state: \.travelPlanner, action: \.travelPlanner))
        case .clipboard:
            ClipboardView(store: store.scope(state: \.clipboard, action: \.clipboard))
        case .settings:
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
        }
    }
}
#endif
