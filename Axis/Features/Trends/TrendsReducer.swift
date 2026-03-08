import ComposableArchitecture
import Foundation

struct AxisTrendClient {
    var computeTrends: @Sendable (Int) -> TrendService.TrendData
}

private enum AxisTrendKey: DependencyKey {
    static let liveValue = AxisTrendClient(
        computeTrends: { windowDays in
            TrendService.shared.computeTrends(windowDays: windowDays)
        }
    )
}

extension DependencyValues {
    var axisTrends: AxisTrendClient {
        get { self[AxisTrendKey.self] }
        set { self[AxisTrendKey.self] = newValue }
    }
}

@Reducer
struct TrendsReducer {
    @ObservableState
    struct State: Equatable {
        var selectedWindow: WindowSize = .week
        var isLoading: Bool = false
        var trendData: TrendDataState?

        enum WindowSize: String, CaseIterable, Identifiable {
            case week = "7D"
            case twoWeeks = "14D"
            case month = "30D"
            case quarter = "90D"

            var id: String { rawValue }
            var days: Int {
                switch self {
                case .week: return 7
                case .twoWeeks: return 14
                case .month: return 30
                case .quarter: return 90
                }
            }
        }

        struct TrendDataState: Equatable {
            // Current period metrics
            var focusMinutes: Int = 0
            var focusSessions: Int = 0
            var pomodorosCompleted: Int = 0
            var prioritiesCompleted: Int = 0
            var prioritiesCreated: Int = 0
            var interactionsLogged: Int = 0
            var uniqueContactsReached: Int = 0
            var placesVisited: Int = 0
            var dadWinsCount: Int = 0

            // Previous period metrics (for comparisons)
            var prevFocusMinutes: Int = 0
            var prevPrioritiesCompleted: Int = 0
            var prevInteractionsLogged: Int = 0
            var prevDadWinsCount: Int = 0

            // Chart data
            var dailyFocusMinutes: [Double] = []
            var dailyInteractions: [Double] = []
            var dailyPrioritiesCompleted: [Double] = []

            // Insights
            var insights: [InsightState] = []

            struct InsightState: Equatable, Identifiable {
                let id: UUID
                var icon: String
                var message: String
                var category: String
            }

            var completionRate: Double {
                guard prioritiesCreated > 0 else { return 0 }
                return Double(prioritiesCompleted) / Double(prioritiesCreated)
            }

            var focusHours: String {
                let hours = focusMinutes / 60
                let mins = focusMinutes % 60
                if hours > 0 { return "\(hours)h \(mins)m" }
                return "\(mins)m"
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case windowChanged(State.WindowSize)
        case trendsLoaded(State.TrendDataState)
    }

    @Dependency(\.axisTrends) var trendClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let window = state.selectedWindow.days
                return .run { send in
                    let data = trendClient.computeTrends(window)
                    let mapped = mapToState(data)
                    await send(.trendsLoaded(mapped))
                }

            case let .windowChanged(newWindow):
                state.selectedWindow = newWindow
                state.isLoading = true
                let window = newWindow.days
                return .run { send in
                    let data = trendClient.computeTrends(window)
                    let mapped = mapToState(data)
                    await send(.trendsLoaded(mapped))
                }

            case let .trendsLoaded(data):
                state.isLoading = false
                state.trendData = data
                return .none
            }
        }
    }
}

private func mapToState(_ data: TrendService.TrendData) -> TrendsReducer.State.TrendDataState {
    TrendsReducer.State.TrendDataState(
        focusMinutes: data.current.focusMinutes,
        focusSessions: data.current.focusSessions,
        pomodorosCompleted: data.current.pomodorosCompleted,
        prioritiesCompleted: data.current.prioritiesCompleted,
        prioritiesCreated: data.current.prioritiesCreated,
        interactionsLogged: data.current.interactionsLogged,
        uniqueContactsReached: data.current.uniqueContactsReached,
        placesVisited: data.current.placesVisited,
        dadWinsCount: data.current.dadWinsCount,
        prevFocusMinutes: data.previous.focusMinutes,
        prevPrioritiesCompleted: data.previous.prioritiesCompleted,
        prevInteractionsLogged: data.previous.interactionsLogged,
        prevDadWinsCount: data.previous.dadWinsCount,
        dailyFocusMinutes: data.dailyFocusMinutes,
        dailyInteractions: data.dailyInteractions,
        dailyPrioritiesCompleted: data.dailyPrioritiesCompleted,
        insights: data.insights.map {
            .init(id: $0.id, icon: $0.icon, message: $0.message, category: $0.category)
        }
    )
}
