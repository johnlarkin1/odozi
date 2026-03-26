import HealthKit

struct SleepStageData: Sendable {
    let totalHours: Double?
    let remHours: Double?
    let deepHours: Double?
    let coreHours: Double?
    let awakeMinutes: Double?
    let sleepOnset: Date?
    let wakeTime: Date?
    let interruptionCount: Int
}

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
        try await fetchSleepStages(for: date)?.totalHours
    }

    func fetchSleepStages(for date: Date) async throws -> SleepStageData? {
        guard let interval = sleepInterval(for: date) else {
            return nil
        }
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let sampleDescriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await sampleDescriptor.result(for: store)

        // Bucket samples by sleep stage
        var coreSamples: [HKCategorySample] = []
        var deepSamples: [HKCategorySample] = []
        var remSamples: [HKCategorySample] = []
        var unspecifiedSamples: [HKCategorySample] = []
        var awakeSamples: [HKCategorySample] = []

        for sample in samples {
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSamples.append(sample)
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSamples.append(sample)
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSamples.append(sample)
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                unspecifiedSamples.append(sample)
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSamples.append(sample)
            default:
                break // Skip inBed and unknown values
            }
        }

        // Compute per-stage durations (merge overlapping intervals per stage)
        let coreSeconds = mergedDuration(from: coreSamples) + mergedDuration(from: unspecifiedSamples)
        let deepSeconds = mergedDuration(from: deepSamples)
        let remSeconds = mergedDuration(from: remSamples)
        let awakeSeconds = mergedDuration(from: awakeSamples)

        let totalSeconds = coreSeconds + deepSeconds + remSeconds

        // Determine sleep onset (earliest asleep sample) and wake time (latest asleep sample end)
        let allAsleepSamples = (coreSamples + deepSamples + remSamples + unspecifiedSamples)
            .sorted { $0.startDate < $1.startDate }
        let sleepOnset = allAsleepSamples.first?.startDate
        let wakeTime = allAsleepSamples.map(\.endDate).max()

        // Count awake interruptions: distinct awake intervals that fall between sleep onset and wake time
        let interruptionCount: Int
        if let onset = sleepOnset, let wake = wakeTime {
            interruptionCount = awakeSamples
                .filter { $0.startDate >= onset && $0.endDate <= wake }
                .sorted { $0.startDate < $1.startDate }
                .reduce(into: (count: 0, lastEnd: Date.distantPast)) { state, sample in
                    if sample.startDate > state.lastEnd {
                        state.count += 1
                    }
                    state.lastEnd = max(state.lastEnd, sample.endDate)
                }.count
        } else {
            interruptionCount = 0
        }

        return SleepStageData(
            totalHours: totalSeconds > 0 ? totalSeconds / 3600.0 : nil,
            remHours: remSeconds > 0 ? remSeconds / 3600.0 : nil,
            deepHours: deepSeconds > 0 ? deepSeconds / 3600.0 : nil,
            coreHours: coreSeconds > 0 ? coreSeconds / 3600.0 : nil,
            awakeMinutes: awakeSeconds > 0 ? awakeSeconds / 60.0 : nil,
            sleepOnset: sleepOnset,
            wakeTime: wakeTime,
            interruptionCount: interruptionCount
        )
    }

    /// Merges overlapping intervals and returns total duration in seconds.
    private func mergedDuration(from samples: [HKCategorySample]) -> TimeInterval {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var totalSeconds: TimeInterval = 0
        var currentStart: Date?
        var currentEnd: Date?

        for sample in sorted {
            if let start = currentStart, let end = currentEnd {
                if sample.startDate <= end {
                    currentEnd = max(end, sample.endDate)
                } else {
                    totalSeconds += end.timeIntervalSince(start)
                    currentStart = sample.startDate
                    currentEnd = sample.endDate
                }
            } else {
                currentStart = sample.startDate
                currentEnd = sample.endDate
            }
        }
        if let start = currentStart, let end = currentEnd {
            totalSeconds += end.timeIntervalSince(start)
        }
        return totalSeconds
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
