import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                scheduleSection
                preferencesSection
                healthSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.axisGold)
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.axisGold.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Text(String(store.userName.prefix(1)).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.axisGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $store.userName.sending(\.userNameChanged))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Axis Commander")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Picker("Default Mode", selection: $store.preferredContextMode.sending(\.preferredContextModeChanged)) {
                ForEach(ContextMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
        } header: {
            Text("Profile")
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            DatePicker("Wake Time", selection: $store.wakeTime.sending(\.wakeTimeChanged), displayedComponents: .hourAndMinute)
            DatePicker("Work Start", selection: $store.workStartTime.sending(\.workStartTimeChanged), displayedComponents: .hourAndMinute)
            DatePicker("Work End", selection: $store.workEndTime.sending(\.workEndTimeChanged), displayedComponents: .hourAndMinute)
        } header: {
            Text("Daily Schedule")
        } footer: {
            Text("Used for Day Brief timing and context mode auto-switching.")
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
            Picker("Default Focus Session", selection: $store.defaultFocusMinutes.sending(\.defaultFocusMinutesChanged)) {
                Text("15 min").tag(15)
                Text("25 min").tag(25)
                Text("45 min").tag(45)
                Text("60 min").tag(60)
            }

            Picker("Daily Steps Goal", selection: $store.stepsGoal.sending(\.stepsGoalChanged)) {
                Text("5,000").tag(5000)
                Text("8,000").tag(8000)
                Text("10,000").tag(10000)
                Text("12,000").tag(12000)
            }

            Toggle("Notifications", isOn: $store.notificationsEnabled.sending(\.notificationsToggled))
            Toggle("Haptic Feedback", isOn: $store.hapticFeedbackEnabled.sending(\.hapticFeedbackToggled))

            Picker("Appearance", selection: $store.darkModeOverride.sending(\.darkModeChanged)) {
                ForEach(SettingsReducer.State.DarkModeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            Toggle("HealthKit Integration", isOn: $store.healthKitEnabled.sending(\.healthKitToggled))

            if store.healthKitEnabled {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(store.healthKitAuthorized ? "Connected" : "Not Authorized")
                        .foregroundStyle(store.healthKitAuthorized ? .green : .orange)
                        .font(.caption)
                }
            }
        } header: {
            Text("Health")
        } footer: {
            Text("Connect to Apple Health for real sleep, steps, and energy data in the Balance tab.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(store.appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Built with")
                Spacer()
                Text("SwiftUI + TCA")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("AXIS — Your personal command center.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}
