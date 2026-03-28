import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

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

    private var mainContent: some View {
        ZStack {
            TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
                // Tab 1: Dashboard
                EADashboardView(
                    store: store.scope(state: \.eaDashboard, action: \.eaDashboard),
                    onNavigateToPlanner: { store.send(.tabSelected(.planner)) },
                    onNavigateToTasks: { store.send(.tabSelected(.tasks)) },
                    onNavigateToProjects: { store.send(.tabSelected(.projects)) },
                    onSettingsTapped: { store.send(.toggleSettings) },
                    onAddTapped: {
                        store.send(.tabSelected(.tasks))
                        store.send(.eaTasks(.showAddTaskSheet))
                    },
                    onCompletedTasksTapped: {
                        store.send(.tabSelected(.tasks))
                        store.send(.eaTasks(.filterChanged(.done)))
                    },
                    onMeetingsTapped: { store.send(.tabSelected(.planner)) },
                    onDeepWorkTapped: { store.send(.tabSelected(.planner)) },
                    onToggleDarkMode: {
                        let current = store.settings.darkModeOverride
                        let next: SettingsReducer.State.DarkModeOption = current == .dark ? .light : .dark
                        store.send(.settings(.darkModeChanged(next)))
                    },
                    isDarkMode: store.settings.darkModeOverride == .dark
                )
                .tabItem {
                    Label("EA", systemImage: "brain.head.profile.fill")
                }
                .tag(AppReducer.State.Tab.dashboard)

                // Tab 2: Calendar
                CalendarTabView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(AppReducer.State.Tab.calendar)

                // Tab 3: AI Chat
                AIChatView(store: store.scope(state: \.aiChat, action: \.aiChat))
                    .tabItem {
                        Label("AI Chat", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .tag(AppReducer.State.Tab.aiChat)

                // Tab 4: Notes
                QuickNotesView(
                    store: store.scope(state: \.quickNotes, action: \.quickNotes)
                )
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(AppReducer.State.Tab.notes)

                // Tab 5: Tasks
                EATaskListView(
                    store: store.scope(state: \.eaTasks, action: \.eaTasks)
                )
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .badge(store.eaTasks.inboxCount > 0 ? store.eaTasks.inboxCount : 0)
                .tag(AppReducer.State.Tab.tasks)

                // Under "More" (iOS auto-creates More tab when >5 tabs)
                ExploreView(
                    store: store.scope(state: \.explore, action: \.explore)
                )
                .tabItem {
                    Label("Explore", systemImage: "map.fill")
                }
                .tag(AppReducer.State.Tab.explore)

                EAPlannerView(
                    store: store.scope(state: \.eaPlanner, action: \.eaPlanner)
                )
                .tabItem {
                    Label("Planner", systemImage: "calendar.badge.clock")
                }
                .tag(AppReducer.State.Tab.planner)

                EAProjectListView(
                    store: store.scope(state: \.eaProjects, action: \.eaProjects)
                )
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(AppReducer.State.Tab.projects)

                SocialCircleView(
                    store: store.scope(state: \.socialCircle, action: \.socialCircle)
                )
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
                .tag(AppReducer.State.Tab.social)

                FamilyHQView(
                    store: store.scope(state: \.familyHQ, action: \.familyHQ)
                )
                .tabItem {
                    Label("FamilyHQ", systemImage: "house.and.flag.fill")
                }
                .tag(AppReducer.State.Tab.familyHQ)

                BalanceView(
                    store: store.scope(state: \.balance, action: \.balance)
                )
                .tabItem {
                    Label("Balance", systemImage: "heart.circle.fill")
                }
                .tag(AppReducer.State.Tab.balance)

                BudgetView(
                    store: store.scope(state: \.budget, action: \.budget)
                )
                .tabItem {
                    Label("Budget", systemImage: "dollarsign.circle.fill")
                }
                .tag(AppReducer.State.Tab.budget)

                TrendsView(
                    store: store.scope(state: \.trends, action: \.trends)
                )
                .tabItem {
                    Label("News", systemImage: "newspaper.fill")
                }
                .tag(AppReducer.State.Tab.trends)

                VoiceMemosView(
                    store: store.scope(state: \.voiceMemos, action: \.voiceMemos)
                )
                .tabItem {
                    Label("Voice Memos", systemImage: "mic.fill")
                }
                .tag(AppReducer.State.Tab.voiceMemos)

                TravelPlannerView(
                    store: store.scope(state: \.travelPlanner, action: \.travelPlanner)
                )
                .tabItem {
                    Label("Travel", systemImage: "airplane")
                }
                .tag(AppReducer.State.Tab.travel)

                ClipboardView(
                    store: store.scope(state: \.clipboard, action: \.clipboard)
                )
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }
                .tag(AppReducer.State.Tab.clipboard)

                SettingsView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppReducer.State.Tab.settings)
            }
            .tint(Color.axisGold)

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
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppReducer.State()) {
            AppReducer()
        }
    )
}
