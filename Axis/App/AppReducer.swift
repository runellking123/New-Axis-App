import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .commandCenter
        var contextMode: ContextMode = .work
        var commandCenter = CommandCenterReducer.State()
        var showQuickCapture = false
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
        case tabSelected(State.Tab)
        case contextModeChanged(ContextMode)
        case commandCenter(CommandCenterReducer.Action)
        case toggleQuickCapture
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.commandCenter, action: \.commandCenter) {
            CommandCenterReducer()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            case let .contextModeChanged(mode):
                state.contextMode = mode
                return .none
            case .toggleQuickCapture:
                state.showQuickCapture.toggle()
                return .none
            case .commandCenter:
                return .none
            }
        }
    }
}
