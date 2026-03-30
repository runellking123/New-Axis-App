import SwiftUI
import Combine
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>
    @State private var isKeyboardVisible = false

    var body: some View {
        ZStack {
            if store.showOnboarding {
                OnboardingView {
                    store.send(.completeOnboarding)
                }
                .transition(.opacity)
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.showOnboarding)
        .onAppear { store.send(.onAppear) }
        .onOpenURL { url in store.send(.handleDeepLink(url)) }
        .preferredColorScheme(colorScheme(for: store.settings.darkModeOverride))
    }

    private func colorScheme(for option: SettingsReducer.State.DarkModeOption) -> ColorScheme? {
        switch option {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Tab Bar Configuration

    private struct TabBarItem {
        let tab: AppReducer.State.Tab
        let title: String
        let icon: String
    }

    private let primaryTabs: [TabBarItem] = [
        TabBarItem(tab: .dashboard, title: "EA", icon: "brain.head.profile.fill"),
        TabBarItem(tab: .calendar, title: "Calendar", icon: "calendar"),
        TabBarItem(tab: .tasks, title: "Workflow", icon: "rectangle.stack.fill"),
        TabBarItem(tab: .voiceMemos, title: "Memos", icon: "mic.fill"),
        TabBarItem(tab: .aiChat, title: "AI Chat", icon: "bubble.left.and.text.bubble.right"),
        TabBarItem(tab: .notes, title: "Notes", icon: "note.text"),
        TabBarItem(tab: .budget, title: "Budget", icon: "dollarsign.circle.fill"),
    ]

    private let overflowTabs: [TabBarItem] = [
        TabBarItem(tab: .explore, title: "Explore", icon: "map.fill"),
        TabBarItem(tab: .social, title: "Social", icon: "person.2.fill"),
        TabBarItem(tab: .familyHQ, title: "FamilyHQ", icon: "house.and.flag.fill"),
        TabBarItem(tab: .balance, title: "Balance", icon: "heart.circle.fill"),
        TabBarItem(tab: .trends, title: "News", icon: "newspaper.fill"),
        TabBarItem(tab: .travel, title: "Travel", icon: "airplane"),
        TabBarItem(tab: .settings, title: "Settings", icon: "gearshape.fill"),
    ]

    @State private var showMoreSheet = false

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                tabContentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar — hidden when keyboard is up
            if !isKeyboardVisible {
                customTabBar
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            moreSheet
        }
        .sheet(isPresented: Binding(
            get: { store.showSettings },
            set: { newValue in
                if !newValue { store.send(.toggleSettings) }
            }
        )) {
            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    @ViewBuilder
    private var tabContentView: some View {
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

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(primaryTabs, id: \.tab) { item in
                tabBarButton(item)
            }
            // More button
            Button {
                showMoreSheet = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                    Text("More")
                        .font(.system(size: 10))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(overflowTabs.contains(where: { $0.tab == store.selectedTab }) ? Color.axisGold : .secondary)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tabBarButton(_ item: TabBarItem) -> some View {
        Button {
            store.send(.tabSelected(item.tab))
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                Text(item.title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(store.selectedTab == item.tab ? Color.axisGold : .secondary)
        }
    }

    private var moreSheet: some View {
        NavigationStack {
            List {
                ForEach(overflowTabs, id: \.tab) { item in
                    Button {
                        showMoreSheet = false
                        store.send(.tabSelected(item.tab))
                    } label: {
                        Label(item.title, systemImage: item.icon)
                            .foregroundStyle(store.selectedTab == item.tab ? Color.axisGold : .primary)
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMoreSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppReducer.State()) {
            AppReducer()
        }
    )
}
