import SwiftUI
import Combine
import ComposableArchitecture
#if os(iOS)
import UIKit
#endif

#if os(iOS)
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

    private let tabsBefore: [TabBarItem] = [
        TabBarItem(tab: .dashboard, title: "EA", icon: "brain.head.profile.fill"),
        TabBarItem(tab: .calendar, title: "Calendar", icon: "calendar"),
    ]

    private let tabsAfter: [TabBarItem] = [
        TabBarItem(tab: .voiceMemos, title: "Memos", icon: "mic.fill"),
        TabBarItem(tab: .aiChat, title: "AI Chat", icon: "bubble.left.and.text.bubble.right"),
        TabBarItem(tab: .tasks, title: "Workflow", icon: "rectangle.stack.fill"),
    ]

    private var primaryTabs: [TabBarItem] { tabsBefore + tabsAfter }

    // Gallery tiles — everything not in the bottom bar
    private struct GalleryTile {
        let tab: AppReducer.State.Tab
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
    }

    private let galleryTiles: [GalleryTile] = [
        GalleryTile(tab: .notes, title: "Notes", subtitle: "Quick capture", icon: "note.text", color: .orange),
        GalleryTile(tab: .budget, title: "Budget", subtitle: "Bills & expenses", icon: "dollarsign.circle.fill", color: .green),
        GalleryTile(tab: .explore, title: "Explore", subtitle: "Nearby places", icon: "map.fill", color: .blue),
        GalleryTile(tab: .social, title: "Social", subtitle: "Your circle", icon: "person.2.fill", color: .purple),
        GalleryTile(tab: .familyHQ, title: "FamilyHQ", subtitle: "Family hub", icon: "house.and.flag.fill", color: .indigo),
        GalleryTile(tab: .balance, title: "Balance", subtitle: "Wellness", icon: "heart.circle.fill", color: .pink),
        GalleryTile(tab: .trends, title: "News", subtitle: "Feed & trends", icon: "newspaper.fill", color: .teal),
        GalleryTile(tab: .travel, title: "Travel", subtitle: "Trip planner", icon: "airplane", color: .cyan),
        GalleryTile(tab: .clipboard, title: "Clipboard", subtitle: "Saved clips", icon: "doc.on.clipboard", color: .mint),
        GalleryTile(tab: .settings, title: "Settings", subtitle: "Preferences", icon: "gearshape.fill", color: .gray),
    ]

    @State private var showGallery = false
    @State private var gallerySelectedTab: AppReducer.State.Tab? = nil

    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                if showGallery {
                    if let tab = gallerySelectedTab {
                        galleryDetailWrapper(for: tab)
                            .transition(.move(edge: .trailing))
                    } else {
                        galleryGrid
                            .transition(.move(edge: .leading))
                    }
                } else {
                    tabContentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: gallerySelectedTab)

            if !isKeyboardVisible {
                customTabBar
            }
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

    // MARK: - Gallery Grid

    private var galleryGrid: some View {
        NavigationStack {
            ScrollView {
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(galleryTiles, id: \.tab) { tile in
                        Button {
                            store.send(.tabSelected(tile.tab))
                            gallerySelectedTab = tile.tab
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: tile.icon)
                                    .font(.system(size: 28))
                                    .foregroundStyle(tile.color)
                                Spacer()
                                Text(tile.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(tile.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 100)
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func galleryDetailWrapper(for tab: AppReducer.State.Tab) -> some View {
        galleryDetailView(for: tab)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        // Swipe right to go back
                        if value.translation.width > 80 && abs(value.translation.height) < 100 {
                            gallerySelectedTab = nil
                        }
                    }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        gallerySelectedTab = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Gallery")
                                .font(.body)
                        }
                        .foregroundStyle(Color.axisGold)
                    }
                }
            }
    }

    @ViewBuilder
    private func galleryDetailView(for tab: AppReducer.State.Tab) -> some View {
        switch tab {
        case .notes:
            QuickNotesView(store: store.scope(state: \.quickNotes, action: \.quickNotes))
        case .budget:
            BudgetView(store: store.scope(state: \.budget, action: \.budget))
        case .explore:
            ExploreView(store: store.scope(state: \.explore, action: \.explore))
        case .social:
            SocialCircleView(store: store.scope(state: \.socialCircle, action: \.socialCircle))
        case .familyHQ:
            FamilyHQView(store: store.scope(state: \.familyHQ, action: \.familyHQ))
        case .balance:
            BalanceView(store: store.scope(state: \.balance, action: \.balance))
        case .trends:
            TrendsView(store: store.scope(state: \.trends, action: \.trends))
        case .travel:
            TravelPlannerView(store: store.scope(state: \.travelPlanner, action: \.travelPlanner))
        case .clipboard:
            ClipboardView(store: store.scope(state: \.clipboard, action: \.clipboard))
        case .settings:
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
        default:
            EmptyView()
        }
    }

    // MARK: - Tab Content

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

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabsBefore, id: \.tab) { item in
                tabBarButton(item)
            }
            // Gallery button (between Calendar and Memos)
            Button {
                if showGallery && gallerySelectedTab == nil {
                    showGallery = false
                } else {
                    gallerySelectedTab = nil
                    showGallery = true
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 20))
                    Text("Gallery")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(showGallery ? Color.axisGold : .secondary)
            }
            ForEach(tabsAfter, id: \.tab) { item in
                tabBarButton(item)
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
            showGallery = false
            gallerySelectedTab = nil
            store.send(.tabSelected(item.tab))
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                Text(item.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(!showGallery && store.selectedTab == item.tab ? Color.axisGold : .secondary)
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
#endif
