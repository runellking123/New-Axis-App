import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        ZStack {
            TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
                CommandCenterView(
                    store: store.scope(state: \.commandCenter, action: \.commandCenter)
                )
                .tabItem {
                    Label(AppReducer.State.Tab.commandCenter.title,
                          systemImage: AppReducer.State.Tab.commandCenter.icon)
                }
                .tag(AppReducer.State.Tab.commandCenter)

                WorkSuitePlaceholderView()
                    .tabItem {
                        Label(AppReducer.State.Tab.workSuite.title,
                              systemImage: AppReducer.State.Tab.workSuite.icon)
                    }
                    .tag(AppReducer.State.Tab.workSuite)

                FamilyHQPlaceholderView()
                    .tabItem {
                        Label(AppReducer.State.Tab.familyHQ.title,
                              systemImage: AppReducer.State.Tab.familyHQ.icon)
                    }
                    .tag(AppReducer.State.Tab.familyHQ)

                SocialCirclePlaceholderView()
                    .tabItem {
                        Label(AppReducer.State.Tab.socialCircle.title,
                              systemImage: AppReducer.State.Tab.socialCircle.icon)
                    }
                    .tag(AppReducer.State.Tab.socialCircle)

                ExplorePlaceholderView()
                    .tabItem {
                        Label(AppReducer.State.Tab.explore.title,
                              systemImage: AppReducer.State.Tab.explore.icon)
                    }
                    .tag(AppReducer.State.Tab.explore)

                BalancePlaceholderView()
                    .tabItem {
                        Label(AppReducer.State.Tab.balance.title,
                              systemImage: AppReducer.State.Tab.balance.icon)
                    }
                    .tag(AppReducer.State.Tab.balance)
            }
            .tint(.axisGold)

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
    }
}
