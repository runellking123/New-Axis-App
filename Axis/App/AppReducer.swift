import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .commandCenter
        var contextMode: ContextMode = .work
        var commandCenter = CommandCenterReducer.State()
        var workSuite = WorkSuiteReducer.State()
        var familyHQ = FamilyHQReducer.State()
        var socialCircle = SocialCircleReducer.State()
        var explore = ExploreReducer.State()
        var balance = BalanceReducer.State()
        var settings = SettingsReducer.State()
        var showQuickCapture = false
        var showSettings = false
        var showOnboarding = false
        var userName: String = "Runell"

        enum Tab: Int, CaseIterable, Identifiable {
            case commandCenter = 0
            case workSuite = 1
            case familyHQ = 2
            case socialCircle = 3
            case explore = 4
            case balance = 5

            var id: Int { rawValue }

            var title: String {
                switch self {
                case .commandCenter: return "Command"
                case .workSuite: return "Work"
                case .familyHQ: return "Family"
                case .socialCircle: return "Social"
                case .explore: return "Explore"
                case .balance: return "Balance"
                }
            }

            var icon: String {
                switch self {
                case .commandCenter: return "bolt.fill"
                case .workSuite: return "building.columns.fill"
                case .familyHQ: return "house.fill"
                case .socialCircle: return "person.2.fill"
                case .explore: return "safari.fill"
                case .balance: return "heart.fill"
                }
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case tabSelected(State.Tab)
        case contextModeChanged(ContextMode)
        case commandCenter(CommandCenterReducer.Action)
        case workSuite(WorkSuiteReducer.Action)
        case familyHQ(FamilyHQReducer.Action)
        case socialCircle(SocialCircleReducer.Action)
        case explore(ExploreReducer.Action)
        case balance(BalanceReducer.Action)
        case settings(SettingsReducer.Action)
        case toggleQuickCapture
        case toggleSettings
        case completeOnboarding
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.commandCenter, action: \.commandCenter) {
            CommandCenterReducer()
        }
        Scope(state: \.workSuite, action: \.workSuite) {
            WorkSuiteReducer()
        }
        Scope(state: \.familyHQ, action: \.familyHQ) {
            FamilyHQReducer()
        }
        Scope(state: \.socialCircle, action: \.socialCircle) {
            SocialCircleReducer()
        }
        Scope(state: \.explore, action: \.explore) {
            ExploreReducer()
        }
        Scope(state: \.balance, action: \.balance) {
            BalanceReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let persistence = PersistenceService.shared
                let profile = persistence.getOrCreateProfile()
                state.userName = profile.name
                state.showOnboarding = !profile.onboardingComplete

                // Auto-switch context mode based on time of day
                let hour = Calendar.current.component(.hour, from: Date())
                let workStartHour = Calendar.current.component(.hour, from: profile.workStartTime)
                let workEndHour = Calendar.current.component(.hour, from: profile.workEndTime)

                let autoMode: ContextMode
                if hour < workStartHour {
                    autoMode = .me
                } else if hour < workEndHour {
                    autoMode = .work
                } else {
                    autoMode = .dad
                }
                state.contextMode = autoMode
                state.commandCenter.contextMode = autoMode
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .contextModeChanged(mode):
                state.contextMode = mode
                return .none

            case .toggleQuickCapture:
                state.showQuickCapture.toggle()
                return .none

            case .toggleSettings:
                state.showSettings.toggle()
                return .none

            case .completeOnboarding:
                state.showOnboarding = false
                let persistence = PersistenceService.shared
                state.userName = persistence.getOrCreateProfile().name
                return .none

            case .commandCenter, .workSuite, .familyHQ, .socialCircle, .explore, .balance, .settings:
                return .none
            }
        }
    }
}
