import HealthKit
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "HealthKit")

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
    /// Long-lived instance used for background delivery + observer queries, which require the
    /// `HKHealthStore` and the `HKObserverQuery` objects to stay alive for the app's lifetime.
    /// One-shot fetches may keep using freshly-constructed instances.
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// The sample types we read and want background updates for. (`activeEnergyBurned` is
    /// authorized for workout calories but has no standalone fetch, so it's excluded here.)
    private var backgroundSampleTypes: [HKSampleType] {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKWorkoutType.workoutType()
        ]
    }

    func requestAuthorization() async throws {
        guard HealthKitService.isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.activeEnergyBurned),
            HKWorkoutType.workoutType()
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
        logger.info("HealthKit authorization requested")
    }

    // MARK: - Background delivery

    /// Asks HealthKit to wake the app when new samples land while it's backgrounded.
    ///
    /// Requires the `com.apple.developer.healthkit.background-delivery` entitlement plus a
    /// regenerated provisioning profile. Without it, `enableBackgroundDelivery` throws — we log
    /// and continue so the app still captures via foreground + BGTasks (graceful degradation).
    func enableBackgroundDelivery() async {
        guard HealthKitService.isAvailable else { return }
        for type in backgroundSampleTypes {
            do {
                try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
                logger.info("Enabled background delivery for \(type.identifier, privacy: .public)")
            } catch {
                logger.warning("Background delivery unavailable for \(type.identifier, privacy: .public): \(error.localizedDescription) — is the background-delivery entitlement present?")
            }
        }
    }

    /// Registers one `HKObserverQuery` per read type. Each firing runs the shared snapshot path
    /// (which itself skips HealthKit while the device is locked) and then calls the required
    /// completion handler so iOS keeps delivering. Idempotent — no-op if already observing.
    func startObserving() {
        guard HealthKitService.isAvailable, observerQueries.isEmpty else { return }
        for type in backgroundSampleTypes {
            let typeID = type.identifier
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
                if let error {
                    logger.error("HealthKit observer error for \(typeID, privacy: .public): \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                Task {
                    await HealthKitService.handleObservedChange()
                    completionHandler()
                }
            }
            store.execute(query)
            observerQueries.append(query)
        }
        logger.info("Registered \(self.observerQueries.count) HealthKit observer queries")
    }

    /// Runs the shared snapshot capture + apply in response to a background HealthKit update.
    /// `applySnapshotData` only writes non-nil values and uses `fetchOrCreateToday()`, so this
    /// is safe to run repeatedly and alongside the BGTask / location-wake paths.
    private static func handleObservedChange() async {
        do {
            let container = try DataContainer.create()
            let service = BackgroundSnapshotService()
            let data = await service.captureSnapshot()
            await MainActor.run {
                applySnapshotData(data, to: container.mainContext)
            }
            logger.info("Applied snapshot from HealthKit observer")
        } catch {
            logger.error("Snapshot from HealthKit observer failed: \(error)")
        }
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

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        guard let interval = dayInterval(for: date) else { return nil }
        let type = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
            options: .discreteAverage
        )

        let result = try await descriptor.result(for: store)
        guard let avg = result?.averageQuantity() else { return nil }
        return avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    func fetchWorkouts(for date: Date) async throws -> [WorkoutSummary] {
        guard let interval = dayInterval(for: date) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: store)
        logger.info("Workouts for \(interval.start)–\(interval.end): \(samples.count) found")

        return samples.map { workout in
            WorkoutSummary(
                activityType: workout.workoutActivityType.rawValue,
                activityName: Self.workoutActivityName(workout.workoutActivityType),
                durationSeconds: workout.duration,
                totalCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                totalDistanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                averageHeartRate: nil,
                startDate: workout.startDate,
                endDate: workout.endDate
            )
        }
    }

    // MARK: - Workout Helpers

    // swiftlint:disable:next cyclomatic_complexity
    static func workoutActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Functional Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .martialArts: return "Martial Arts"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Cardio"
        case .climbing: return "Climbing"
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .jumpRope: return "Jump Rope"
        case .golf: return "Golf"
        case .surfingSports: return "Surfing"
        case .snowSports: return "Snow Sports"
        case .skatingSports: return "Skating"
        case .paddleSports: return "Paddle Sports"
        case .badminton: return "Badminton"
        case .volleyball: return "Volleyball"
        case .hockey: return "Hockey"
        case .tableTennis: return "Table Tennis"
        case .handball: return "Handball"
        case .lacrosse: return "Lacrosse"
        case .rugby: return "Rugby"
        case .wrestling: return "Wrestling"
        case .cricket: return "Cricket"
        case .gymnastics: return "Gymnastics"
        case .fencing: return "Fencing"
        case .archery: return "Archery"
        case .fishing: return "Fishing"
        // Unmapped types default to "Workout" with base intensity score 5
        default: return "Workout"
        }
    }

    static func computeIntensityScore(for workouts: [WorkoutSummary]) -> Int? {
        guard !workouts.isEmpty else { return nil }

        // Base score from workout type
        // Unmapped activity names (i.e. "Workout") default to base score 5
        let typeScores: [String: Int] = [
            "Walking": 3, "Yoga": 3, "Pilates": 3, "Cooldown": 2,
            "Cycling": 5, "Swimming": 6, "Elliptical": 5, "Rowing": 6, "Dance": 5,
            "Running": 7, "Hiking": 6, "Strength": 6, "Functional Strength": 6,
            "Core Training": 5, "Stair Climbing": 6, "Cross Training": 7, "Cardio": 6,
            "HIIT": 8, "Martial Arts": 7, "Basketball": 7, "Soccer": 7, "Tennis": 6,
            "Climbing": 7, "Boxing": 8, "Kickboxing": 8, "Jump Rope": 7,
            "Golf": 3, "Surfing": 6, "Snow Sports": 6, "Skating": 5,
            "Paddle Sports": 5, "Badminton": 5, "Volleyball": 5, "Hockey": 7,
            "Table Tennis": 4, "Handball": 7, "Lacrosse": 7, "Rugby": 8,
            "Wrestling": 8, "Cricket": 4, "Gymnastics": 6, "Fencing": 6,
            "Archery": 2, "Fishing": 2
        ]

        guard let longestWorkout = workouts.max(by: { $0.durationSeconds < $1.durationSeconds }) else { return nil }
        var score = typeScores[longestWorkout.activityName] ?? 5

        // Duration modifier
        let maxDurationMinutes = longestWorkout.durationSeconds / 60
        if maxDurationMinutes > 75 {
            score += 2
        } else if maxDurationMinutes > 45 {
            score += 1
        }

        // Calorie modifier
        let totalCalories = workouts.compactMap(\.totalCalories).reduce(0, +)
        if totalCalories > 700 {
            score += 2
        } else if totalCalories > 400 {
            score += 1
        }

        return min(max(score, 1), 10)
    }
}
