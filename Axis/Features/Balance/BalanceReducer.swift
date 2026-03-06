import ComposableArchitecture
import Foundation

@Reducer
struct BalanceReducer {
    @ObservableState
    struct State: Equatable {
        var energyScore: Int = 7
        var sleepHours: Double = 0
        var stepsToday: Int = 0
        var stepsGoal: Int = 10000
        var stressLevel: StressLevel = .moderate
        var balanceMeter: BalanceMeter = .init()
        var weeklyLog: [DayLog] = []
        var showLogEntry = false
        var newLogMood = "good"
        var newLogNotes = ""
        var selectedSection: Section = .dashboard
        var healthKitConnected = false
        var weeklyReport: AIService.WeeklyReport?
        var weeklyReportGeneratedAt: Date?

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
            var workPercent: Double = 45
            var familyPercent: Double = 25
            var selfPercent: Double = 15
            var socialPercent: Double = 15
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
        case newLogMoodChanged(String)
        case newLogNotesChanged(String)
        case addLogEntry
        case deleteLogEntry(UUID)
        case healthDataLoaded(sleep: Double, steps: Int, energy: Int)
        case loadWeeklyReport
        case weeklyReportLoaded(AIService.WeeklyReport)
    }

    @Dependency(\.axisHealth) var health
    @Dependency(\.axisHaptics) var haptics
    @Dependency(\.axisAI) var ai

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.weeklyLog.isEmpty {
                    state.weeklyLog = Self.sampleWeeklyLog()
                }
                let profile = PersistenceService.shared.getOrCreateProfile()
                state.stepsGoal = profile.stepsGoal
                HapticService.setEnabled(profile.hapticFeedbackEnabled)
                // Try to load HealthKit data via async effect
                return .run { send in
                    let data = (isAuth: await health.isAuthorized(), isAvail: await health.isAvailable())

                    if data.isAuth || data.isAvail {
                        if !data.isAuth {
                            let authorized = await health.requestAuthorization()
                            guard authorized else { return }
                        }
                        let snapshot = await health.fetchAllData()
                        await send(.healthDataLoaded(sleep: snapshot.sleep, steps: snapshot.steps, energy: snapshot.energy))
                    }
                }

            case let .healthDataLoaded(sleep, steps, energy):
                state.sleepHours = sleep
                state.stepsToday = steps
                state.energyScore = energy
                state.healthKitConnected = true
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
                    let report = ai.generateWeeklyReport()
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
                }
                return .none

            case let .newLogMoodChanged(mood):
                state.newLogMood = mood
                return .none

            case let .newLogNotesChanged(notes):
                state.newLogNotes = notes
                return .none

            case .addLogEntry:
                let entry = State.DayLog(
                    id: UUID(),
                    date: Date(),
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

            case .loadWeeklyReport:
                let report = ai.generateWeeklyReport()
                state.weeklyReport = report
                state.weeklyReportGeneratedAt = Date()
                return .none

            case let .weeklyReportLoaded(report):
                state.weeklyReport = report
                state.weeklyReportGeneratedAt = Date()
                return .none
            }
        }
    }

    private static func sampleWeeklyLog() -> [State.DayLog] {
        let cal = Calendar.current
        return [
            .init(id: UUID(), date: cal.date(byAdding: .day, value: -1, to: Date())!, mood: "good", energyScore: 7, notes: "Productive day. Hit all my meetings."),
            .init(id: UUID(), date: cal.date(byAdding: .day, value: -2, to: Date())!, mood: "great", energyScore: 9, notes: "Great workout in the morning. Felt amazing all day."),
            .init(id: UUID(), date: cal.date(byAdding: .day, value: -3, to: Date())!, mood: "okay", energyScore: 5, notes: "Rough sleep. Managed to push through."),
            .init(id: UUID(), date: cal.date(byAdding: .day, value: -4, to: Date())!, mood: "good", energyScore: 7, notes: "Family dinner was great."),
            .init(id: UUID(), date: cal.date(byAdding: .day, value: -5, to: Date())!, mood: "rough", energyScore: 3, notes: "Overloaded with deadlines. Need to recalibrate."),
        ]
    }
}
