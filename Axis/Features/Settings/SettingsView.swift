import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                locationSection
                scheduleSection
                executiveAssistantSection
                eaNotificationsSection
                preferencesSection
                healthSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Save any pending changes
                        store.send(.saveProfile)
                        // Dismiss (works when presented as sheet)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.axisGold)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Location

    private var locationSection: some View {
        Section {
            HStack {
                TextField("City, ZIP, or State", text: $store.locationSearchText.sending(\.locationSearchTextChanged))
                    .textContentType(.addressCity)
                    .onSubmit { store.send(.locationSearchSubmitted) }

                Button {
                    store.send(.locationSearchSubmitted)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.axisGold)
                }
                .disabled(store.locationSearchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if store.isUsingCustomLocation {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.orange)
                    Text(store.locationDisplayName)
                        .font(.subheadline)
                    Spacer()
                    Button("Reset") {
                        store.send(.useMyLocation)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.axisGold)
                }
            }

            Button {
                store.send(.useMyLocation)
            } label: {
                Label("Use My Location", systemImage: "location.fill")
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Used for weather and nearby recommendations. Search by city name, ZIP code, or state.")
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

    // MARK: - Executive Assistant

    private var executiveAssistantSection: some View {
        Section {
            DatePicker("Daily Plan Time", selection: $store.eaPlanGenerationTime.sending(\.eaPlanGenerationTimeChanged), displayedComponents: .hourAndMinute)

            DatePicker("Quiet Hours Start", selection: $store.eaQuietHoursStart.sending(\.eaQuietHoursStartChanged), displayedComponents: .hourAndMinute)

            DatePicker("Quiet Hours End", selection: $store.eaQuietHoursEnd.sending(\.eaQuietHoursEndChanged), displayedComponents: .hourAndMinute)

            Picker("Default Task Duration", selection: $store.eaDefaultTaskDuration.sending(\.eaDefaultTaskDurationChanged)) {
                Text("15 min").tag(15)
                Text("25 min").tag(25)
                Text("30 min").tag(30)
                Text("45 min").tag(45)
                Text("60 min").tag(60)
            }

            Picker("Morning Energy", selection: $store.eaMorningEnergyPreference.sending(\.eaMorningEnergyChanged)) {
                Text("Deep Work").tag("deepWork")
                Text("Light Work").tag("lightWork")
            }

            Picker("Afternoon Energy", selection: $store.eaAfternoonEnergyPreference.sending(\.eaAfternoonEnergyChanged)) {
                Text("Deep Work").tag("deepWork")
                Text("Light Work").tag("lightWork")
            }
        } header: {
            Text("Executive Assistant")
        } footer: {
            Text("Configure how your AI assistant plans your day and manages tasks.")
        }
    }

    // MARK: - EA Notifications

    private var eaNotificationsSection: some View {
        Section {
            Toggle("Daily Plan Ready", isOn: $store.eaNotifyDailyPlan.sending(\.eaNotifyDailyPlanToggled))
            Toggle("Deadline Warnings", isOn: $store.eaNotifyDeadlines.sending(\.eaNotifyDeadlinesToggled))
            Toggle("Focus Block Start", isOn: $store.eaNotifyFocusBlock.sending(\.eaNotifyFocusBlockToggled))
            Toggle("Meeting Reminders", isOn: $store.eaNotifyMeetings.sending(\.eaNotifyMeetingsToggled))
            Toggle("At-Risk Tasks", isOn: $store.eaNotifyAtRisk.sending(\.eaNotifyAtRiskToggled))
            Toggle("Inbox Pending", isOn: $store.eaNotifyInbox.sending(\.eaNotifyInboxToggled))
        } header: {
            Text("EA Notifications")
        } footer: {
            Text("Individual toggles for each notification category. Quiet hours are respected.")
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
