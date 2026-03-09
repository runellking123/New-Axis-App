import ComposableArchitecture
import Foundation

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var userName: String = ""
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

        // Location
        var locationSearchText: String = ""
        var locationDisplayName: String = ""
        var isUsingCustomLocation: Bool = false
        var locationPermissionStatus: String = "Not Determined"

        // EA Settings
        var eaQuietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        var eaQuietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        var eaPlanGenerationTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        var eaMorningEnergyPreference: String = "deepWork"
        var eaAfternoonEnergyPreference: String = "lightWork"
        var eaDefaultTaskDuration: Int = 25
        var eaCategories: [String] = ["University", "Consulting", "Personal"]
        var eaNotifyDailyPlan: Bool = true
        var eaNotifyDeadlines: Bool = true
        var eaNotifyFocusBlock: Bool = true
        var eaNotifyMeetings: Bool = true
        var eaNotifyAtRisk: Bool = true
        var eaNotifyInbox: Bool = true

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
        case locationSearchTextChanged(String)
        case locationSearchSubmitted
        case locationSearchResult(Bool, String)
        case useMyLocation
        // EA Settings
        case eaQuietHoursStartChanged(Date)
        case eaQuietHoursEndChanged(Date)
        case eaPlanGenerationTimeChanged(Date)
        case eaMorningEnergyChanged(String)
        case eaAfternoonEnergyChanged(String)
        case eaDefaultTaskDurationChanged(Int)
        case eaNotifyDailyPlanToggled(Bool)
        case eaNotifyDeadlinesToggled(Bool)
        case eaNotifyFocusBlockToggled(Bool)
        case eaNotifyMeetingsToggled(Bool)
        case eaNotifyAtRiskToggled(Bool)
        case eaNotifyInboxToggled(Bool)
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
                if state.notificationsEnabled {
                    notifications.scheduleDayBrief(time)
                }
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
                    let wakeTime = state.wakeTime
                    return .run { send in
                        let granted = await notifications.requestAuthorization()
                        if granted {
                            notifications.scheduleDayBrief(wakeTime)
                        }
                        await send(.saveProfile)
                    }
                }
                notifications.cancelDayBrief()
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

            case let .locationSearchTextChanged(text):
                state.locationSearchText = text
                return .none

            case .locationSearchSubmitted:
                let query = state.locationSearchText
                guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                return .run { send in
                    let locationService = LocationService.shared
                    let success = await locationService.searchCity(query)
                    let name = await MainActor.run { locationService.currentLocationName }
                    await send(.locationSearchResult(success, name))
                }

            case let .locationSearchResult(success, name):
                if success {
                    state.isUsingCustomLocation = true
                    state.locationDisplayName = name
                    state.locationSearchText = ""
                }
                return .none

            case .useMyLocation:
                state.isUsingCustomLocation = false
                state.locationSearchText = ""
                let locService = LocationService.shared
                locService.requestPermission()
                locService.resetToCurrentLocation()
                // Update display after a moment for location to resolve
                let currentName = locService.currentLocationName
                state.locationDisplayName = currentName.isEmpty ? "Locating..." : currentName
                return .run { send in
                    try? await Task.sleep(for: .seconds(2))
                    let name = await MainActor.run { LocationService.shared.currentLocationName }
                    if !name.isEmpty {
                        await send(.locationSearchResult(true, name))
                    }
                }

            // EA Settings
            case let .eaQuietHoursStartChanged(time):
                state.eaQuietHoursStart = time
                return .none
            case let .eaQuietHoursEndChanged(time):
                state.eaQuietHoursEnd = time
                return .none
            case let .eaPlanGenerationTimeChanged(time):
                state.eaPlanGenerationTime = time
                if state.eaNotifyDailyPlan {
                    NotificationService.shared.scheduleDailyPlanReady(at: time)
                }
                return .none
            case let .eaMorningEnergyChanged(pref):
                state.eaMorningEnergyPreference = pref
                return .none
            case let .eaAfternoonEnergyChanged(pref):
                state.eaAfternoonEnergyPreference = pref
                return .none
            case let .eaDefaultTaskDurationChanged(mins):
                state.eaDefaultTaskDuration = mins
                return .none
            case let .eaNotifyDailyPlanToggled(on):
                state.eaNotifyDailyPlan = on
                if on { NotificationService.shared.scheduleDailyPlanReady(at: state.eaPlanGenerationTime) }
                else { NotificationService.shared.cancelAll(withPrefix: "ea-plan-ready") }
                return .none
            case let .eaNotifyDeadlinesToggled(on):
                state.eaNotifyDeadlines = on
                if !on { NotificationService.shared.cancelAll(withPrefix: "ea-deadline") }
                return .none
            case let .eaNotifyFocusBlockToggled(on):
                state.eaNotifyFocusBlock = on
                if !on { NotificationService.shared.cancelAll(withPrefix: "ea-focus") }
                return .none
            case let .eaNotifyMeetingsToggled(on):
                state.eaNotifyMeetings = on
                if !on { NotificationService.shared.cancelAll(withPrefix: "ea-meeting") }
                return .none
            case let .eaNotifyAtRiskToggled(on):
                state.eaNotifyAtRisk = on
                if !on { NotificationService.shared.cancelAll(withPrefix: "ea-atrisk") }
                return .none
            case let .eaNotifyInboxToggled(on):
                state.eaNotifyInbox = on
                if !on { NotificationService.shared.cancelAll(withPrefix: "ea-inbox") }
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
