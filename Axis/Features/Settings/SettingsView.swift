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
                if !store.calendarAccessGranted || store.availableCalendars.isEmpty {
                    calendarsAccessSection
                } else {
                    ForEach(calendarsGroupedBySource, id: \.source) { group in
                        calendarSourceSection(group)
                    }
                    if store.calendarSelectionConfigured {
                        Section {
                            Button("Include All Calendars") {
                                store.send(.includeAllCalendars)
                            }
                            .foregroundStyle(Color.axisGold)
                        } footer: {
                            Text("Only enabled calendars appear in Day Brief, daily plans, schedule analysis, and calendar AI actions.")
                        }
                    }
                }
                executiveAssistantSection
                eaNotificationsSection
                preferencesSection
                healthSection
                aiChatSection
                dataManagementSection
                securitySection
                dataExportSection
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
            .scrollDismissesKeyboard(.immediately)
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                AxisAvatar(
                    content: .initials(String(store.userName.prefix(2))),
                    size: 60,
                    tint: Color.axisGold
                )

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

    // MARK: - Daily Schedule

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

    // MARK: - Calendars

    private var calendarsAccessSection: some View {
        Section {
            if !store.calendarAccessGranted {
                Label("Calendar access required", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text("Allow calendar access so AXIS can list your accounts and choose which feed daily analysis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No calendars found. Add accounts in iPhone Settings → Calendar → Accounts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Calendars for Daily Analysis")
        }
    }

    private func calendarSourceSection(_ group: (source: String, sourceType: String, calendars: [CalendarService.CalendarInfo])) -> some View {
        Section {
            ForEach(group.calendars) { cal in
                Toggle(isOn: Binding(
                    get: { store.includedCalendarIDs.contains(cal.id) },
                    set: { store.send(.calendarInclusionToggled(cal.id, $0)) }
                )) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(calendarColor(cal.colorComponents))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cal.title)
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: 4) {
                                Text(cal.sourceType)
                                if cal.isDefault {
                                    Text("· Default")
                                }
                                if !cal.allowsContentModifications {
                                    Text("· Read-only")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(Color.axisGold)
            }
        } header: {
            Label(group.source, systemImage: iconForSourceType(group.sourceType))
        } footer: {
            if group.source == calendarsGroupedBySource.last?.source && !store.calendarSelectionConfigured {
                Text("Only enabled calendars appear in Day Brief, daily plans, schedule analysis, and calendar AI actions. Accounts stay linked in iOS Settings — this only controls what AXIS includes.")
            }
        }
    }

    private var calendarsGroupedBySource: [(source: String, sourceType: String, calendars: [CalendarService.CalendarInfo])] {
        let grouped = Dictionary(grouping: store.availableCalendars, by: \.sourceTitle)
        return grouped.keys.sorted().compactMap { key in
            guard let calendars = grouped[key], let first = calendars.first else { return nil }
            return (source: key, sourceType: first.sourceType, calendars: calendars)
        }
    }

    private func calendarColor(_ components: [CGFloat]) -> Color {
        guard components.count >= 3 else { return Color.axisCobalt }
        let alpha = components.count >= 4 ? components[3] : 1
        return Color(red: components[0], green: components[1], blue: components[2], opacity: alpha)
    }

    private func iconForSourceType(_ type: String) -> String {
        switch type {
        case "iCloud": return "icloud.fill"
        case "Exchange / Outlook": return "building.2.fill"
        case "CalDAV / Google": return "globe"
        case "On My iPhone": return "iphone"
        case "Subscribed": return "link"
        case "Birthdays": return "gift.fill"
        default: return "calendar"
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

    // MARK: - AI Chat

    private var aiChatSection: some View {
        Section {
            SecureField("Anthropic API Key", text: Binding(
                get: { MultiProviderChatService.shared.anthropicAPIKey },
                set: { MultiProviderChatService.shared.anthropicAPIKey = $0 }
            ))
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif

            HStack {
                Text("Selected Model")
                Spacer()
                Text(MultiProviderChatService.shared.selectedModel.displayName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(MultiProviderChatService.shared.isConfigured ? "Ready" : "API Key Needed")
                    .foregroundStyle(MultiProviderChatService.shared.isConfigured ? .green : .orange)
            }
        } header: {
            Text("AI Chat")
        } footer: {
            Text("Get an API key at console.anthropic.com. Your key is saved on this device and persists across launches.")
        }
    }

    // MARK: - Data Management

    @State private var showDeleteContactsAlert = false

    private var dataManagementSection: some View {
        Section {
            Button("Delete All Imported Contacts", role: .destructive) {
                showDeleteContactsAlert = true
            }
            .alert("Delete All Contacts?", isPresented: $showDeleteContactsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    PersistenceService.shared.deleteAllContacts()
                }
            } message: {
                Text("This will permanently remove all contacts from Social Circle. Your Apple Contacts are not affected.")
            }
        } header: {
            Text("Data Management")
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section {
            Toggle("Require Face ID", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "axis_require_faceid") },
                set: { UserDefaults.standard.set($0, forKey: "axis_require_faceid") }
            ))
        } header: {
            Text("Security")
        }
    }

    // MARK: - Data Export

    private var dataExportSection: some View {
        Section {
            Button("Export All Data (JSON)") {
                exportAllData()
            }
        } header: {
            Text("Data Export")
        } footer: {
            Text("Export all tasks, projects, contacts, and chat history")
        }
    }

    private func exportAllData() {
        let persistence = PersistenceService.shared
        var export: [String: Any] = [:]
        export["exportDate"] = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        export["tasks"] = persistence.fetchEATasks().map { [
            "title": $0.title,
            "status": $0.status,
            "category": $0.category,
            "priority": $0.priority
        ] as [String: String] }
        export["projects"] = persistence.fetchEAProjects().map { [
            "title": $0.title,
            "status": $0.status,
            "category": $0.category
        ] as [String: String] }
        export["contacts"] = persistence.fetchContacts().map { [
            "name": $0.name,
            "phone": $0.phone,
            "tier": $0.tier
        ] as [String: String] }
        export["chatThreads"] = persistence.fetchChatThreads().map { [
            "title": $0.title,
            "date": "\($0.updatedAt)"
        ] as [String: String] }

        if let jsonData = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("AXIS_Export_\(Int(Date().timeIntervalSince1970)).json")
            try? jsonData.write(to: tempURL)
            PlatformServices.share(items: [tempURL])
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

#Preview {
    SettingsView(
        store: Store(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
    )
}
