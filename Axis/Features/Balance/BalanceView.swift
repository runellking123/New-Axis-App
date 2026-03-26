import ComposableArchitecture
import SwiftUI

struct BalanceView: View {
    @Bindable var store: StoreOf<BalanceReducer>
    @State private var showSleepDetail = false
    @State private var showStepsDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $store.selectedSection.sending(\.sectionChanged)) {
                    ForEach(BalanceReducer.State.Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        switch store.selectedSection {
                        case .dashboard:
                            dashboardSection
                        case .log:
                            weeklyLogSection
                        case .report:
                            weeklyReportSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Balance")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.green)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.selectedSection == .log {
                        Button {
                            store.send(.toggleLogEntry)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showLogEntry },
                set: { newValue in
                    if !newValue { store.send(.dismissLogEntry) }
                }
            )) {
                addLogSheet
            }
            .sheet(isPresented: $showSleepDetail) {
                SleepDetailView(sleepHours: store.sleepHours)
            }
            .sheet(isPresented: $showStepsDetail) {
                StepsDetailView(stepsToday: store.stepsToday, stepsGoal: store.stepsGoal)
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Dashboard

    private var dashboardSection: some View {
        VStack(spacing: 16) {
            // HealthKit hint when not connected
            if !store.healthKitConnected {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect Apple Health")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Grant Health access here to sync sleep, steps, calories, heart rate, and standing hours directly into Balance.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            store.send(.requestHealthAccess)
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Connect Health")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            if store.healthKitConnected {
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health Sync")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(store.lastHealthSync.map { "Last synced \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.send(.requestHealthAccess)
                        } label: {
                            if store.isSyncingHealth {
                                ProgressView()
                            } else {
                                Label("Sync", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
            }

            // Energy Score - big display
            energyScoreCard

            // Stats grid
            HStack(spacing: 12) {
                Button { showSleepDetail = true } label: {
                    WidgetCardView(
                        icon: "bed.double.fill",
                        title: "Sleep",
                        value: store.sleepHours > 0 ? String(format: "%.1fh", store.sleepHours) : "--",
                        subtitle: store.sleepHours > 0 ? (store.sleepHours >= 7 ? "Well rested" : "Need more rest") : "No data",
                        color: store.sleepHours >= 7 ? .blue : .orange
                    )
                }
                .buttonStyle(.plain)

                Button { showStepsDetail = true } label: {
                    WidgetCardView(
                        icon: "figure.walk",
                        title: "Steps",
                        value: store.stepsToday > 0 ? formatSteps(store.stepsToday) : "--",
                        subtitle: store.stepsToday > 0 ? "\(Int(store.stepsProgress * 100))% of goal" : "No data",
                        color: store.stepsProgress >= 0.7 ? .green : .orange
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                WidgetCardView(
                    icon: "flame.fill",
                    title: "Calories",
                    value: store.activeCalories > 0 ? "\(store.activeCalories)" : "--",
                    subtitle: "active today",
                    color: .orange
                )
                WidgetCardView(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: store.heartRate > 0 ? "\(Int(store.heartRate)) bpm" : "--",
                    subtitle: "latest reading",
                    color: .red
                )
            }

            HStack(spacing: 12) {
                WidgetCardView(
                    icon: "figure.stand",
                    title: "Stand",
                    value: store.standHours > 0 ? "\(store.standHours)h" : "--",
                    subtitle: "stood today",
                    color: .green
                )
                WidgetCardView(
                    icon: "target",
                    title: "Step Goal",
                    value: "\(store.stepsGoal)",
                    subtitle: "daily target",
                    color: .blue
                )
            }

            // Sleep Goal Progress
            sleepGoalCard

            // Stress level
            stressCard

            // Balance Meter
            balanceMeterCard

            // Recovery suggestions
            recoverySuggestionsCard

            // Water tracker
            waterTrackerCard

            // Mood check-in
            moodCheckInCard
        }
    }

    // MARK: - Sleep Goal Card

    private var sleepGoalCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "bed.double.fill").foregroundStyle(.indigo)
                    Text("Sleep Goal").font(.headline)
                    Spacer()
                    Text("\(String(format: "%.1f", store.sleepGoalHours))h goal")
                        .font(.caption).foregroundStyle(.secondary)
                }
                let progress = store.sleepHours > 0 ? min(store.sleepHours / store.sleepGoalHours, 1.0) : 0
                ProgressView(value: progress)
                    .tint(.indigo)
                if store.sleepHours > 0 {
                    Text("\(String(format: "%.1f", store.sleepHours))h slept — \(Int(progress * 100))% of goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Stepper("Goal: \(String(format: "%.1f", store.sleepGoalHours))h",
                            value: $store.sleepGoalHours.sending(\.sleepGoalChanged),
                            in: 4...12, step: 0.5)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Water Tracker Card

    private var waterTrackerCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill").foregroundStyle(.cyan)
                    Text("Water").font(.headline)
                    Spacer()
                    Text("\(store.waterGlasses)/\(store.waterGoal) glasses")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(min(store.waterGlasses, store.waterGoal)), total: Double(store.waterGoal))
                    .tint(.cyan)
                Button { store.send(.addWater) } label: {
                    Label("+1 Glass", systemImage: "plus.circle.fill")
                        .font(.caption).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.cyan.opacity(0.15))
                        .foregroundStyle(.cyan)
                        .clipShape(.capsule)
                }
            }
        }
    }

    // MARK: - Mood Check-in Card

    private var moodCheckInCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "face.smiling").foregroundStyle(.yellow)
                    Text("Mood").font(.headline)
                    Spacer()
                }
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { level in
                        Button { store.send(.setMood(level)) } label: {
                            Text(Self.moodEmoji(level))
                                .font(.title2)
                                .opacity(store.moodToday == level ? 1.0 : 0.4)
                                .scaleEffect(store.moodToday == level ? 1.2 : 1.0)
                        }
                    }
                }
            }
        }
    }

    private static func moodEmoji(_ level: Int) -> String {
        switch level {
        case 1: return "\u{1F62B}"
        case 2: return "\u{1F615}"
        case 3: return "\u{1F610}"
        case 4: return "\u{1F642}"
        case 5: return "\u{1F604}"
        default: return "\u{1F610}"
        }
    }

    // MARK: - Energy Score Card

    private var energyScoreCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                    Text("Energy Level")
                        .font(.headline)
                    Spacer()
                    Text(store.energyLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(energyColor(store.energyColor).opacity(0.15))
                        .foregroundStyle(energyColor(store.energyColor))
                        .clipShape(Capsule())
                }

                // Score display
                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { level in
                        Button {
                            store.send(.energyScoreChanged(level))
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(level <= store.energyScore
                                      ? energyBarColor(level)
                                      : Color(.systemGray4))
                                .frame(height: 32)
                        }
                    }
                }

                HStack {
                    Text("Depleted")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.energyScore)/10")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(energyColor(store.energyColor))
                    Spacer()
                    Text("Energized")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func energyBarColor(_ level: Int) -> Color {
        if level <= 3 { return .red }
        if level <= 5 { return .orange }
        if level <= 7 { return .blue }
        return .green
    }

    // MARK: - Stress Card

    private var stressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: store.stressLevel.icon)
                        .foregroundStyle(stressColor(store.stressLevel.color))
                    Text("Stress Level")
                        .font(.headline)
                    Spacer()
                    Text(store.stressLevel.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(stressColor(store.stressLevel.color).opacity(0.15))
                        .foregroundStyle(stressColor(store.stressLevel.color))
                        .clipShape(Capsule())
                }

                Text(store.stressLevel.suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Balance Meter

    private var balanceMeterCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.green)
                    Text("Time Balance")
                        .font(.headline)
                }

                VStack(spacing: 8) {
                    balanceBar(label: "Work", percent: store.balanceMeter.workPercent, color: Color.axisGold)
                    balanceBar(label: "Family", percent: store.balanceMeter.familyPercent, color: .blue)
                    balanceBar(label: "Self", percent: store.balanceMeter.selfPercent, color: .green)
                    balanceBar(label: "Social", percent: store.balanceMeter.socialPercent, color: .purple)
                }
            }
        }
    }

    private func balanceBar(label: String, percent: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * (percent / 100))
                }
            }
            .frame(height: 12)

            Text("\(Int(percent))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Recovery Suggestions

    private var recoverySuggestionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.green)
                    Text("Recovery Suggestions")
                        .font(.headline)
                }

                ForEach(store.recoverySuggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.top, 1)
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Weekly Log

    private var weeklyLogSection: some View {
        VStack(spacing: 12) {
            // Mood trend
            if !store.weeklyLog.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Moods")
                            .font(.headline)
                        HStack(spacing: 6) {
                            ForEach(store.weeklyLog.prefix(7).reversed()) { log in
                                VStack(spacing: 4) {
                                    Image(systemName: log.moodIcon)
                                        .font(.title3)
                                        .foregroundStyle(moodColor(log.moodColor))
                                    Text(log.date.shortDateString)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            // Log entries
            ForEach(store.weeklyLog) { log in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: log.moodIcon)
                                .foregroundStyle(moodColor(log.moodColor))
                            Text(log.mood.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(log.date.relativeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Energy: \(log.energyScore)/10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !log.notes.isEmpty {
                            Text(log.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                    }
                }
            }

            if store.weeklyLog.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.secondary)
                        Text("No entries yet. Tap + to log how you're feeling.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Add Log Sheet

    private var addLogSheet: some View {
        NavigationStack {
            Form {
                Section("How are you feeling?") {
                    Picker("Mood", selection: $store.newLogMood.sending(\.newLogMoodChanged)) {
                        Label("Great", systemImage: "sun.max.fill").tag("great")
                        Label("Good", systemImage: "cloud.sun.fill").tag("good")
                        Label("Okay", systemImage: "cloud.fill").tag("okay")
                        Label("Rough", systemImage: "cloud.rain.fill").tag("rough")
                    }
                    .pickerStyle(.inline)
                }

                Section("Notes (optional)") {
                    TextField("What's on your mind?", text: $store.newLogNotes.sending(\.newLogNotesChanged), axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text("Energy Score")
                        Spacer()
                        Text("\(store.energyScore)/10")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissLogEntry) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.addLogEntry) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Weekly Report

    private var weeklyReportSection: some View {
        VStack(spacing: 16) {
            Picker("Window", selection: $store.reportRangeDays.sending(\.reportRangeChanged)) {
                Text("7D").tag(7)
                Text("14D").tag(14)
                Text("30D").tag(30)
            }
            .pickerStyle(.segmented)

            if let report = store.weeklyReport {
                HStack {
                    if let generatedAt = store.weeklyReportGeneratedAt {
                        Text("Updated \(generatedAt.relativeString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.send(.loadWeeklyReport)
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }

                // Summary card
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .foregroundStyle(.green)
                            Text("Weekly Summary")
                                .font(.headline)
                        }
                        Text(report.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    WidgetCardView(
                        icon: "checkmark.circle.fill",
                        title: "Priorities",
                        value: "\(report.completedPriorities)/\(report.totalPriorities)",
                        subtitle: "completed",
                        color: report.completedPriorities > 0 ? .green : .orange
                    )
                    WidgetCardView(
                        icon: "trophy.fill",
                        title: "Dad Wins",
                        value: "\(report.dadWinsCount)",
                        subtitle: "this week",
                        color: .yellow
                    )
                    WidgetCardView(
                        icon: "person.2.fill",
                        title: "People",
                        value: "\(report.contactsReachedOut)",
                        subtitle: "connected with",
                        color: .purple
                    )
                    WidgetCardView(
                        icon: "safari.fill",
                        title: "Places",
                        value: "\(report.placesExplored)",
                        subtitle: "explored",
                        color: .orange
                    )
                }

                // Highlights
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Highlights")
                                .font(.headline)
                        }
                        ForEach(report.highlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.top, 1)
                                Text(highlight)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Areas for improvement
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Next Week")
                                .font(.headline)
                        }
                        ForEach(report.improvementAreas, id: \.self) { area in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .padding(.top, 1)
                                Text(area)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green.opacity(0.5))
                        Text("Your weekly report")
                            .font(.headline)
                        Text("See how you balanced work, family, and personal time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            store.send(.loadWeeklyReport)
                        } label: {
                            Text("Generate Report")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(.green)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }

    private func energyColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    private func stressColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    private func moodColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}
