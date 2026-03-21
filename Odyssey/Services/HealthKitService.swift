import HealthKit

actor HealthKitService {
    private let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard HealthKitService.isAvailable else { return }

        var readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKCategoryType(.sleepAnalysis)
        ]

        #if os(watchOS)
            readTypes.insert(HKQuantityType(.heartRate))
        #endif

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchSteps(for date: Date) async throws -> Int? {
        guard let interval = dayInterval(for: date) else { return nil }
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )

        let result = try await descriptor.result(for: store)
        guard let sum = result?.sumQuantity() else { return nil }
        return Int(sum.doubleValue(for: HKUnit.count()))
    }

    func fetchWalkingDistance(for date: Date) async throws -> Double? {
        guard let interval = dayInterval(for: date) else { return nil }
        let type = HKQuantityType(.distanceWalkingRunning)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )

        let result = try await descriptor.result(for: store)
        guard let sum = result?.sumQuantity() else { return nil }
        return sum.doubleValue(for: HKUnit.meter())
    }

    func fetchSleepHours(for date: Date) async throws -> Double? {
        guard let interval = sleepInterval(for: date) else { return nil }
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let sampleDescriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await sampleDescriptor.result(for: store)

        // Filter to asleep states only (not inBed)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]

        // Merge overlapping intervals to avoid double-counting across sources (Watch + iPhone)
        let sortedSamples = samples
            .filter { asleepValues.contains($0.value) }
            .sorted { $0.startDate < $1.startDate }

        var mergedSeconds: TimeInterval = 0
        var currentStart: Date?
        var currentEnd: Date?

        for sample in sortedSamples {
            if let start = currentStart, let end = currentEnd {
                if sample.startDate <= end {
                    currentEnd = max(end, sample.endDate)
                } else {
                    mergedSeconds += end.timeIntervalSince(start)
                    currentStart = sample.startDate
                    currentEnd = sample.endDate
                }
            } else {
                currentStart = sample.startDate
                currentEnd = sample.endDate
            }
        }
        if let start = currentStart, let end = currentEnd {
            mergedSeconds += end.timeIntervalSince(start)
        }

        return mergedSeconds > 0 ? mergedSeconds / 3600.0 : nil
    }

    private func dayInterval(for date: Date) -> DateInterval? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func sleepInterval(for date: Date) -> DateInterval? {
        // Look at previous evening (8 PM) through current morning (noon)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let sleepStart = calendar.date(byAdding: .hour, value: -4, to: start),
              let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: start) else { return nil }
        return DateInterval(start: sleepStart, end: sleepEnd)
    }

    #if os(watchOS)
        func fetchAverageHeartRate(for date: Date) async throws -> Double? {
            guard let interval = dayInterval(for: date) else { return nil }
            let type = HKQuantityType(.heartRate)
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

            let descriptor = HKStatisticsQueryDescriptor(
                predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
                options: .discreteAverage
            )

            let result = try await descriptor.result(for: store)
            guard let avg = result?.averageQuantity() else { return nil }
            return avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
    #endif
}
