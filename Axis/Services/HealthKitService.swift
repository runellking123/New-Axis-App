import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private(set) var isAuthorized = false
    private(set) var sleepHours: Double = 0
    private(set) var stepsToday: Int = 0
    private(set) var activeCalories: Int = 0
    private(set) var heartRate: Double = 0
    private(set) var standHours: Int = 0

    var energyScore: Int {
        // Composite score based on sleep + activity
        var score = 5 // base
        if sleepHours >= 7 { score += 2 } else if sleepHours >= 6 { score += 1 } else { score -= 1 }
        if stepsToday >= 8000 { score += 2 } else if stepsToday >= 5000 { score += 1 }
        if activeCalories >= 300 { score += 1 }
        return min(max(score, 1), 10)
    }

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    func fetchAllData() async {
        guard isAuthorized else { return }
        async let sleep = fetchSleepHours()
        async let steps = fetchSteps()
        async let calories = fetchActiveCalories()
        async let hr = fetchHeartRate()
        async let stand = fetchStandHours()

        let (s, st, c, h, standValue) = await (sleep, steps, calories, hr, stand)
        sleepHours = s
        stepsToday = st
        activeCalories = c
        heartRate = h
        standHours = standValue
    }

    // MARK: - Sleep

    private func fetchSleepHours() async -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        // Look at sleep from last night (past 24 hours)
        guard let startDate = calendar.date(byAdding: .hour, value: -24, to: now) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            // Filter for asleep states only (not inBed)
            let asleepSamples = samples.filter { sample in
                let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                return value == .asleepCore || value == .asleepDeep || value == .asleepREM || value == .asleepUnspecified
            }
            let totalSeconds = asleepSamples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            return totalSeconds / 3600.0
        } catch {
            return 0
        }
    }

    // MARK: - Steps

    private func fetchSteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Active Calories

    private func fetchActiveCalories() async -> Int {
        guard let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let cals = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(cals))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate

    private func fetchHeartRate() async -> Double {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            return samples.first?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Stand Hours

    private func fetchStandHours() async -> Int {
        guard let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: standType, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            let stoodHours = samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
            return stoodHours.count
        } catch {
            return 0
        }
    }
}
