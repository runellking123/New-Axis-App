import ComposableArchitecture
import Foundation

@Reducer
struct BalanceReducer {
    @ObservableState
    struct State: Equatable {
        var energyScore: Int = 0
        var sleepHours: Double = 0
        var stepsToday: Int = 0
        var stepsGoal: Int = 10000
        var activeCalories: Int = 0
        var heartRate: Double = 0
        var standHours: Int = 0
        var stressLevel: StressLevel = .moderate
        var balanceMeter: BalanceMeter = .init()
        var weeklyLog: [DayLog] = []
        var showLogEntry = false
        var newLogMood = "good"
        var newLogNotes = ""
        var newLogDate = Date()
        var selectedSection: Section = .dashboard
        var healthKitConnected = false
        var weeklyReport: AIService.WeeklyReport?
        var weeklyReportGeneratedAt: Date?
        var reportRangeDays: Int = 7
        var isSyncingHealth = false
        var lastHealthSync: Date?
        var waterGlasses: Int = 0
        var waterGoal: Int = 8
        var moodToday: Int = 0  // 0=not set, 1-5 scale
        var sleepGoalHours: Double = 7.0

        // Energy check-ins
        var todayCheckIns: [CheckInState] = []
        var weeklyEnergyAverages: [Double] = []  // 7 days
        var showCheckIn: Bool = false
        var checkInLevel: Int = 5
        var checkInNote: String = ""

        struct CheckInState: Equatable, Identifiable {
            let id: UUID
            var level: Int
            var note: String
            var timestamp: Date
            var timeLabel: String
        }

        var todayAverageEnergy: Double {
            guard !todayCheckIns.isEmpty else { return Double(energyScore) }
            return Double(todayCheckIns.reduce(0) { $0 + $1.level }) / Double(todayCheckIns.count)
        }

        enum Section: String, CaseIterable, Equatable {
            case dashboard = "Dashboard"
            case log = "Weekly Log"
            case report = "Report"
        }

        enum StressLevel: String, CaseIterable, Equatable {
            case low = "Low"
            case moderate = "Moderate"
            case high = "High"
            case critical = "Critical"

            var color: String {
                switch self {
                case .low: return "green"
                case .moderate: return "yellow"
                case .high: return "orange"
                case .critical: return "red"
                }
            }

            var icon: String {
                switch self {
                case .low: return "leaf.fill"
                case .moderate: return "wind"
                case .high: return "flame.fill"
                case .critical: return "exclamationmark.triangle.fill"
                }
            }

            var suggestion: String {
                switch self {
                case .low: return "Great balance. Keep it up!"
                case .moderate: return "Consider a short walk or breathing exercise."
                case .high: return "Time to step away. Block 30 min for recovery."
                case .critical: return "Your schedule is overloaded. Cancel or delegate something today."
                }
            }
        }

        struct BalanceMeter: Equatable {
            var workPercent: Double = 0
            var familyPercent: Double = 0
            var selfPercent: Double = 0
            var socialPercent: Double = 0
        }

        struct DayLog: Equatable, Identifiable {
            let id: UUID
            var date: Date
            var mood: String // "great", "good", "okay", "rough"
            var energyScore: Int
            var notes: String

            var moodIcon: String {
                switch mood {
                case "great": return "sun.max.fill"
                case "good": return "cloud.sun.fill"
                case "okay": return "cloud.fill"
                case "rough": return "cloud.rain.fill"
                default: return "circle"
                }
            }

            var moodColor: String {
                switch mood {
                case "great": return "green"
                case "good": return "blue"
                case "okay": return "orange"
                case "rough": return "red"
                default: return "gray"
                }
            }
        }

        var stepsProgress: Double {
            min(Double(stepsToday) / Double(stepsGoal), 1.0)
        }

        var energyLabel: String {
            switch energyScore {
            case 8...10: return "Energized"
            case 5...7: return "Steady"
            case 3...4: return "Low"
            default: return "Depleted"
            }
        }

        var energyColor: String {
            switch energyScore {
            case 8...10: return "green"
            case 5...7: return "blue"
            case 3...4: return "orange"
            default: return "red"
            }
        }

        var recoverySuggestions: [String] {
            var suggestions: [String] = []
            if sleepHours < 7 && sleepHours > 0 {
                suggestions.append("Aim for 7+ hours of sleep tonight")
            }
            if stepsToday < stepsGoal / 2 {
                suggestions.append("Take a 15-minute walk to boost energy")
            }
            if stressLevel == .high || stressLevel == .critical {
                suggestions.append("Do a 5-minute breathing exercise")
            }
            if energyScore < 5 {
                suggestions.append("Consider a power nap (20 min max)")
            }
            if suggestions.isEmpty {
                suggestions.append("You're doing great — maintain the momentum!")
            }
            return suggestions
        }
    }

    enum Action: Equatable {
        case onAppear
        case sectionChanged(State.Section)
        case energyScoreChanged(Int)
        case toggleLogEntry
        case dismissLogEntry
        case requestHealthAccess
        case healthAccessUnavailable
        case newLogMoodChanged(String)
        case newLogNotesChanged(String)
        case newLogDateChanged(Date)
        case addLogEntry
        case deleteLogEntry(UUID)
        case healthDataLoaded(sleep: Double, steps: Int, energy: Int, calories: Int, heartRate: Double, standHours: Int)
        case loadWeeklyReport
        case reportRangeChanged(Int)
        case weeklyReportLoaded(AIService.WeeklyReport)
        case addWater
        case setMood(Int)
        case sleepGoalChanged(Double)
        // Energy check-ins
        case showCheckInSheet
        case dismissCheckIn
        case checkInLevelChanged(Int)
        case checkInNoteChanged(String)
        case submitCheckIn
        case checkInsLoaded([State.CheckInState])
        case weeklyAveragesLoaded([Double])
        case exportData
    }

    @Dependency(\.axisHealth) var health
    @Dependency(\.axisHaptics) var haptics
    @Dependency(\.axisAI) var ai

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let profile = PersistenceService.shared.getOrCreateProfile()
                state.stepsGoal = profile.stepsGoal
                HapticService.setEnabled(profile.hapticFeedbackEnabled)
                // Load persisted water, mood, sleep goal
                state.waterGlasses = UserDefaults.standard.integer(forKey: "axis_water_\(Self.todayKey())")
                state.moodToday = UserDefaults.standard.integer(forKey: "axis_mood_\(Self.todayKey())")
                state.sleepGoalHours = UserDefaults.standard.double(forKey: "axis_sleep_goal")
                if state.sleepGoalHours == 0 { state.sleepGoalHours = 7.0 }
                state.isSyncingHealth = true
                // Load today's check-ins
                let today = Date()
                let fetched = PersistenceService.shared.fetchEnergyCheckIns(for: today)
                let tf = DateFormatter()
                tf.dateFormat = "h:mm a"
                state.todayCheckIns = fetched.map { c in
                    State.CheckInState(id: c.uuid, level: c.level, note: c.note, timestamp: c.timestamp, timeLabel: tf.string(from: c.timestamp))
                }
                // Load weekly averages
                let cal = Calendar.current
                var averages: [Double] = []
                for i in (0..<7).reversed() {
                    let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: today))!
                    let dayCheckIns = PersistenceService.shared.fetchEnergyCheckIns(for: day)
                    if dayCheckIns.isEmpty {
                        averages.append(0)
                    } else {
                        averages.append(Double(dayCheckIns.reduce(0) { $0 + $1.level }) / Double(dayCheckIns.count))
                    }
                }
                state.weeklyEnergyAverages = averages
                return .send(.requestHealthAccess)

            case .requestHealthAccess:
                state.isSyncingHealth = true
                return .run { send in
                    let data = (isAuth: await health.isAuthorized(), isAvail: await health.isAvailable())
                    guard data.isAvail else {
                        await send(.healthAccessUnavailable)
                        return
                    }
                    if !data.isAuth {
                        let authorized = await health.requestAuthorization()
                        guard authorized else {
                            await send(.healthAccessUnavailable)
                            return
                        }
                    }
                    let snapshot = await health.fetchAllData()
                    await send(.healthDataLoaded(
                        sleep: snapshot.sleep,
                        steps: snapshot.steps,
                        energy: snapshot.energy,
                        calories: snapshot.calories,
                        heartRate: snapshot.heartRate,
                        standHours: snapshot.standHours
                    ))
                }

            case .healthAccessUnavailable:
                state.isSyncingHealth = false
                state.healthKitConnected = false
                return .none

            case let .healthDataLoaded(sleep, steps, energy, calories, heartRate, standHours):
                state.sleepHours = sleep
                state.stepsToday = steps
                state.energyScore = energy
                state.activeCalories = calories
                state.heartRate = heartRate
                state.standHours = standHours
                state.healthKitConnected = true
                state.isSyncingHealth = false
                state.lastHealthSync = Date()
                // Auto-adjust stress based on energy
                if energy >= 8 {
                    state.stressLevel = .low
                } else if energy >= 5 {
                    state.stressLevel = .moderate
                } else if energy >= 3 {
                    state.stressLevel = .high
                } else {
                    state.stressLevel = .critical
                }
                return .none

            case let .sectionChanged(section):
                state.selectedSection = section
                if section == .report, state.weeklyReport == nil {
                    let report = ai.generateWeeklyReport(state.reportRangeDays)
                    state.weeklyReport = report
                    state.weeklyReportGeneratedAt = Date()
                }
                return .none

            case let .energyScoreChanged(score):
                state.energyScore = score
                if score >= 8 {
                    state.stressLevel = .low
                } else if score >= 5 {
                    state.stressLevel = .moderate
                } else if score >= 3 {
                    state.stressLevel = .high
                } else {
                    state.stressLevel = .critical
                }
                haptics.selection()
                return .none

            case .toggleLogEntry:
                state.showLogEntry.toggle()
                if state.showLogEntry {
                    state.newLogMood = "good"
                    state.newLogNotes = ""
                    state.newLogDate = Date()
                }
                return .none

            case .dismissLogEntry:
                state.showLogEntry = false
                return .none

            case let .newLogMoodChanged(mood):
                state.newLogMood = mood
                return .none

            case let .newLogNotesChanged(notes):
                state.newLogNotes = notes
                return .none

            case let .newLogDateChanged(date):
                state.newLogDate = date
                return .none

            case .addLogEntry:
                let entry = State.DayLog(
                    id: UUID(),
                    date: state.newLogDate,
                    mood: state.newLogMood,
                    energyScore: state.energyScore,
                    notes: state.newLogNotes
                )
                state.weeklyLog.insert(entry, at: 0)
                state.showLogEntry = false
                haptics.notificationSuccess()
                return .none

            case let .deleteLogEntry(id):
                state.weeklyLog.removeAll { $0.id == id }
                return .none

            case let .reportRangeChanged(days):
                state.reportRangeDays = days
                let report = ai.generateWeeklyReport(days)
                state.weeklyReport = report
                state.weeklyReportGeneratedAt = Date()
                return .none

            case .loadWeeklyReport:
                let report = ai.generateWeeklyReport(state.reportRangeDays)
                state.weeklyReport = report
                state.weeklyReportGeneratedAt = Date()
                return .none

            case let .weeklyReportLoaded(report):
                state.weeklyReport = report
                state.weeklyReportGeneratedAt = Date()
                return .none

            case .addWater:
                state.waterGlasses += 1
                UserDefaults.standard.set(state.waterGlasses, forKey: "axis_water_\(Self.todayKey())")
                return .none

            case let .setMood(mood):
                state.moodToday = mood
                UserDefaults.standard.set(mood, forKey: "axis_mood_\(Self.todayKey())")
                return .none

            case let .sleepGoalChanged(hours):
                state.sleepGoalHours = hours
                UserDefaults.standard.set(hours, forKey: "axis_sleep_goal")
                return .none

            case .showCheckInSheet:
                state.checkInLevel = 5
                state.checkInNote = ""
                state.showCheckIn = true
                return .none

            case .dismissCheckIn:
                state.showCheckIn = false
                return .none

            case let .checkInLevelChanged(level):
                state.checkInLevel = level
                return .none

            case let .checkInNoteChanged(note):
                state.checkInNote = note
                return .none

            case .submitCheckIn:
                let checkIn = EnergyCheckIn(level: state.checkInLevel, note: state.checkInNote)
                PersistenceService.shared.saveEnergyCheckIn(checkIn)
                state.showCheckIn = false
                haptics.notificationSuccess()
                // Reload
                let today = Date()
                let fetched = PersistenceService.shared.fetchEnergyCheckIns(for: today)
                let tf = DateFormatter()
                tf.dateFormat = "h:mm a"
                state.todayCheckIns = fetched.map { c in
                    State.CheckInState(id: c.uuid, level: c.level, note: c.note, timestamp: c.timestamp, timeLabel: tf.string(from: c.timestamp))
                }
                return .none

            case let .checkInsLoaded(checkIns):
                state.todayCheckIns = checkIns
                return .none

            case let .weeklyAveragesLoaded(averages):
                state.weeklyEnergyAverages = averages
                return .none

            case .exportData:
                var csv = "AXIS Balance & Energy Report\n"
                csv += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n\n"

                // Today's check-ins
                csv += "Today's Energy Check-Ins\n"
                csv += "Time,Level,Note\n"
                for c in state.todayCheckIns {
                    csv += "\(c.timeLabel),\(c.level),\"\(c.note)\"\n"
                }
                csv += "\nAverage Energy: \(String(format: "%.1f", state.todayAverageEnergy))\n"

                // HealthKit
                csv += "\nHealthKit Data\n"
                csv += "Sleep Hours,\(String(format: "%.1f", state.sleepHours))\n"
                csv += "Steps,\(state.stepsToday)\n"
                csv += "Active Calories,\(state.activeCalories)\n"
                csv += "Heart Rate,\(String(format: "%.0f", state.heartRate))\n"
                csv += "Stand Hours,\(state.standHours)\n"

                // Mood & Water
                let moods = ["", "Rough", "Low", "Okay", "Good", "Great"]
                csv += "\nMood Today,\(state.moodToday > 0 && state.moodToday < moods.count ? moods[state.moodToday] : "Not Set")\n"
                csv += "Water Glasses,\(state.waterGlasses)/\(state.waterGoal)\n"

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("AXIS_Balance_Report.csv")
                try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
                PlatformServices.share(items: [tempURL])
                return .none
            }
        }
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
