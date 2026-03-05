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
                CommandCenterView(
                    store: store.scope(state: \.commandCenter, action: \.commandCenter),
                    onSettingsTapped: { store.send(.toggleSettings) }
                )
                .tabItem {
                    Label(AppReducer.State.Tab.commandCenter.title,
                          systemImage: AppReducer.State.Tab.commandCenter.icon)
                }
                .tag(AppReducer.State.Tab.commandCenter)

                WorkSuiteView(
                    store: store.scope(state: \.workSuite, action: \.workSuite)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.workSuite.title,
                          systemImage: AppReducer.State.Tab.workSuite.icon)
                }
                .tag(AppReducer.State.Tab.workSuite)

                FamilyHQView(
                    store: store.scope(state: \.familyHQ, action: \.familyHQ)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.familyHQ.title,
                          systemImage: AppReducer.State.Tab.familyHQ.icon)
                }
                .tag(AppReducer.State.Tab.familyHQ)

                SocialCircleView(
                    store: store.scope(state: \.socialCircle, action: \.socialCircle)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.socialCircle.title,
                          systemImage: AppReducer.State.Tab.socialCircle.icon)
                }
                .tag(AppReducer.State.Tab.socialCircle)

                ExploreView(
                    store: store.scope(state: \.explore, action: \.explore)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.explore.title,
                          systemImage: AppReducer.State.Tab.explore.icon)
                }
                .tag(AppReducer.State.Tab.explore)

                BalanceView(
                    store: store.scope(state: \.balance, action: \.balance)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.balance.title,
                          systemImage: AppReducer.State.Tab.balance.icon)
                }
                .tag(AppReducer.State.Tab.balance)
            }
            .tint(Color.axisGold)

            // Quick Capture overlay
            if store.showQuickCapture {
                QuickCaptureView(
                    onDismiss: { store.send(.toggleQuickCapture) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(duration: 0.3), value: store.showQuickCapture)
        .sheet(isPresented: Binding(
            get: { store.showSettings },
            set: { _ in store.send(.toggleSettings) }
        )) {
            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
        }
    }
}
