import ComposableArchitecture
import Foundation

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var userName: String = "Runell"
        var wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 30)) ?? Date()
        var workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        var workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
        var preferredContextMode: ContextMode = .work
        var stepsGoal: Int = 10000
        var defaultFocusMinutes: Int = 25
        var notificationsEnabled: Bool = true
        var hapticFeedbackEnabled: Bool = true
        var healthKitEnabled: Bool = false
        var healthKitAuthorized: Bool = false
        var darkModeOverride: DarkModeOption = .system
        var appVersion: String = "1.0.0"

        enum DarkModeOption: String, CaseIterable, Equatable, Identifiable {
            case system = "System"
            case light = "Light"
            case dark = "Dark"
            var id: String { rawValue }
        }
    }

    enum Action: Equatable {
        case onAppear
        case userNameChanged(String)
        case wakeTimeChanged(Date)
        case workStartTimeChanged(Date)
        case workEndTimeChanged(Date)
        case preferredContextModeChanged(ContextMode)
        case stepsGoalChanged(Int)
        case defaultFocusMinutesChanged(Int)
        case notificationsToggled(Bool)
        case hapticFeedbackToggled(Bool)
        case healthKitToggled(Bool)
        case healthKitAuthResult(Bool)
        case darkModeChanged(State.DarkModeOption)
        case saveProfile
    }

    @Dependency(\.axisPersistence) var persistence
    @Dependency(\.axisHealth) var health
    @Dependency(\.axisNotifications) var notifications

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let profile = persistence.getOrCreateProfile()
                state.userName = profile.name
                state.wakeTime = profile.wakeTime
                state.workStartTime = profile.workStartTime
                state.workEndTime = profile.workEndTime
                state.preferredContextMode = ContextMode(rawValue: profile.preferredContextMode.capitalized) ?? .work
                state.stepsGoal = profile.stepsGoal
                state.defaultFocusMinutes = profile.defaultFocusMinutes
                state.notificationsEnabled = profile.notificationsEnabled
                state.hapticFeedbackEnabled = profile.hapticFeedbackEnabled
                HapticService.setEnabled(profile.hapticFeedbackEnabled)
                return .run { send in
                    let isAuth = await health.isAuthorized()
                    if isAuth {
                        await send(.healthKitAuthResult(true))
                    }
                }

            case let .userNameChanged(name):
                state.userName = name
                return .send(.saveProfile)

            case let .wakeTimeChanged(time):
                state.wakeTime = time
                return .send(.saveProfile)

            case let .workStartTimeChanged(time):
                state.workStartTime = time
                return .send(.saveProfile)

            case let .workEndTimeChanged(time):
                state.workEndTime = time
                return .send(.saveProfile)

            case let .preferredContextModeChanged(mode):
                state.preferredContextMode = mode
                return .send(.saveProfile)

            case let .stepsGoalChanged(goal):
                state.stepsGoal = goal
                return .send(.saveProfile)

            case let .defaultFocusMinutesChanged(mins):
                state.defaultFocusMinutes = mins
                return .send(.saveProfile)

            case let .notificationsToggled(enabled):
                state.notificationsEnabled = enabled
                if enabled {
                    return .run { _ in
                        _ = await notifications.requestAuthorization()
                    }
                }
                return .send(.saveProfile)

            case let .hapticFeedbackToggled(enabled):
                state.hapticFeedbackEnabled = enabled
                HapticService.setEnabled(enabled)
                return .send(.saveProfile)

            case let .healthKitToggled(enabled):
                state.healthKitEnabled = enabled
                if enabled {
                    return .run { send in
                        let result = await health.requestAuthorization()
                        await send(.healthKitAuthResult(result))
                    }
                }
                return .none

            case let .darkModeChanged(option):
                state.darkModeOverride = option
                return .none

            case let .healthKitAuthResult(authorized):
                state.healthKitAuthorized = authorized
                if !authorized {
                    state.healthKitEnabled = false
                }
                return .none

            case .saveProfile:
                let profile = persistence.getOrCreateProfile()
                profile.name = state.userName
                profile.wakeTime = state.wakeTime
                profile.workStartTime = state.workStartTime
                profile.workEndTime = state.workEndTime
                profile.preferredContextMode = state.preferredContextMode.rawValue.lowercased()
                profile.stepsGoal = state.stepsGoal
                profile.defaultFocusMinutes = state.defaultFocusMinutes
                profile.notificationsEnabled = state.notificationsEnabled
                profile.hapticFeedbackEnabled = state.hapticFeedbackEnabled
                persistence.updateUserProfile()
                return .none
            }
        }
    }
}
