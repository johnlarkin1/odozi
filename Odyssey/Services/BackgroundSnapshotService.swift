import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "BackgroundSnapshot")

struct SnapshotData: Sendable {
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let state: String?
    let country: String?
    let stepCount: Int?
    let walkingDistanceMeters: Double?
    let sleepHours: Double?
    let sleepREMHours: Double?
    let sleepDeepHours: Double?
    let sleepCoreHours: Double?
    let sleepAwakeMinutes: Double?
    let sleepOnset: Date?
    let sleepInterruptionCount: Int?
    let workoutDataJSON: Data?
    let workoutCount: Int?
    let totalWorkoutMinutes: Double?
    let workoutIntensityScore: Int?
    let restingHeartRate: Double?
    let averageHeartRate: Double?
    let screenTimeSeconds: Double?
    let pickups: Int?
}

actor BackgroundSnapshotService {
    private let locationService = LocationCaptureService()
    private let healthKitService = HealthKitService()

    func captureSnapshot() async -> SnapshotData {
        let today = Calendar.current.startOfDay(for: Date())

        // Run location and HealthKit concurrently
        async let locationResult = captureLocation()
        async let healthResult = captureHealthData(for: today)
        let screenTimeResult = readScreenTimeFromDefaults()

        let location = await locationResult
        let health = await healthResult

        // Encode workout data — only compute summary fields if encoding succeeds
        var workoutJSON: Data?
        var workoutCount: Int?
        var totalMinutes: Double?
        var intensityScore: Int?
        if !health.workouts.isEmpty {
            do {
                workoutJSON = try JSONEncoder().encode(health.workouts)
                workoutCount = health.workouts.count
                totalMinutes = health.workouts.reduce(0) { $0 + $1.durationSeconds } / 60.0
                intensityScore = HealthKitService.computeIntensityScore(for: health.workouts)
            } catch {
                logger.error("Failed to encode workout data: \(error)")
            }
        }

        return SnapshotData(
            latitude: location?.latitude,
            longitude: location?.longitude,
            city: location?.city,
            state: location?.state,
            country: location?.country,
            stepCount: health.steps,
            walkingDistanceMeters: health.distance,
            sleepHours: health.sleep?.totalHours,
            sleepREMHours: health.sleep?.remHours,
            sleepDeepHours: health.sleep?.deepHours,
            sleepCoreHours: health.sleep?.coreHours,
            sleepAwakeMinutes: health.sleep?.awakeMinutes,
            sleepOnset: health.sleep?.sleepOnset,
            sleepInterruptionCount: health.sleep?.interruptionCount,
            workoutDataJSON: workoutJSON,
            workoutCount: workoutCount,
            totalWorkoutMinutes: totalMinutes,
            workoutIntensityScore: intensityScore,
            restingHeartRate: health.restingHeartRate,
            averageHeartRate: health.averageHeartRate,
            screenTimeSeconds: screenTimeResult?.seconds,
            pickups: screenTimeResult?.pickups
        )
    }

    private func captureLocation() async -> LocationSnapshot? {
        do {
            return try await locationService.captureCurrentLocation()
        } catch {
            logger.error("Location capture failed: \(error)")
            return nil
        }
    }

    private struct HealthData: Sendable {
        let steps: Int?
        let distance: Double?
        let sleep: SleepStageData?
        let workouts: [WorkoutSummary]
        let restingHeartRate: Double?
        let averageHeartRate: Double?
    }

    private func captureHealthData(for date: Date) async -> HealthData {
        guard HealthKitService.isAvailable else {
            return HealthData(steps: nil, distance: nil, sleep: nil, workouts: [], restingHeartRate: nil, averageHeartRate: nil)
        }

        var steps: Int?
        var distance: Double?
        var sleep: SleepStageData?
        var workouts: [WorkoutSummary] = []
        var restingHR: Double?
        var averageHR: Double?

        do {
            steps = try await healthKitService.fetchSteps(for: date)
        } catch {
            logger.error("Steps fetch failed: \(error)")
        }

        do {
            distance = try await healthKitService.fetchWalkingDistance(for: date)
        } catch {
            logger.error("Walking distance fetch failed: \(error)")
        }

        do {
            sleep = try await healthKitService.fetchSleepStages(for: date)
        } catch {
            logger.error("Sleep stages fetch failed: \(error)")
        }

        do {
            workouts = try await healthKitService.fetchWorkouts(for: date)
        } catch {
            logger.error("Workouts fetch failed: \(error)")
        }

        do {
            restingHR = try await healthKitService.fetchRestingHeartRate(for: date)
        } catch {
            logger.error("Resting heart rate fetch failed: \(error)")
        }

        do {
            averageHR = try await healthKitService.fetchAverageHeartRate(for: date)
        } catch {
            logger.error("Average heart rate fetch failed: \(error)")
        }

        return HealthData(
            steps: steps, distance: distance, sleep: sleep,
            workouts: workouts, restingHeartRate: restingHR, averageHeartRate: averageHR
        )
    }

    private func readScreenTimeFromDefaults() -> (seconds: Double, pickups: Int)? {
        SharedDefaults.getScreenTime()
    }
}

@MainActor
func applySnapshotData(_ data: SnapshotData, to context: ModelContext) {
    let repository = DailyEntryRepository(context: context)

    do {
        let entry = try repository.fetchOrCreateToday()

        applyLocationData(from: data, to: entry)
        applyHealthKitData(from: data, to: entry)
        try applySleepScore(for: entry, data: data, context: context)
        applyWorkoutAndHeartRateData(from: data, to: entry)
        applyScreenTimeData(from: data, to: entry)

        entry.updatedAt = Date()
        entry.needsSync = true

        try context.save()
    } catch {
        logger.error("Failed to save snapshot: \(error)")
    }
}

private func applyLocationData(from data: SnapshotData, to entry: DailyEntry) {
    if entry.latitude == nil, let lat = data.latitude { entry.latitude = lat }
    if entry.longitude == nil, let lon = data.longitude { entry.longitude = lon }
    if entry.city == nil, let city = data.city { entry.city = city }
    if entry.state == nil, let state = data.state { entry.state = state }
    if entry.country == nil, let country = data.country { entry.country = country }
    if entry.locationCapturedAt == nil, data.latitude != nil { entry.locationCapturedAt = Date() }
}

private func applyHealthKitData(from data: SnapshotData, to entry: DailyEntry) {
    if let steps = data.stepCount { entry.stepCount = steps }
    if let distance = data.walkingDistanceMeters { entry.walkingDistanceMeters = distance }
    if let sleep = data.sleepHours { entry.sleepHours = sleep }
    if let rem = data.sleepREMHours { entry.sleepREMHours = rem }
    if let deep = data.sleepDeepHours { entry.sleepDeepHours = deep }
    if let core = data.sleepCoreHours { entry.sleepCoreHours = core }
    if let awake = data.sleepAwakeMinutes { entry.sleepAwakeMinutes = awake }
    if let onset = data.sleepOnset { entry.sleepOnset = onset }
    if let interruptions = data.sleepInterruptionCount { entry.sleepInterruptionCount = interruptions }
}

private func applySleepScore(for entry: DailyEntry, data: SnapshotData, context: ModelContext) throws {
    guard data.sleepHours != nil else { return }
    let calendar = Calendar.current
    let entryDate = entry.date
    let thirteenDaysAgo = calendar.date(byAdding: .day, value: -13, to: entryDate) ?? entryDate
    let recentDescriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate { $0.date >= thirteenDaysAgo && $0.date < entryDate },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    let recentEntries = try context.fetch(recentDescriptor)
    entry.sleepScore = SleepScoreService.computeScore(for: entry, recentEntries: recentEntries)?.total
}

private func applyWorkoutAndHeartRateData(from data: SnapshotData, to entry: DailyEntry) {
    if let json = data.workoutDataJSON { entry.workoutDataJSON = json }
    if let count = data.workoutCount { entry.workoutCount = count }
    if let minutes = data.totalWorkoutMinutes { entry.totalWorkoutMinutes = minutes }
    if let intensity = data.workoutIntensityScore { entry.workoutIntensityScore = intensity }
    if let rhr = data.restingHeartRate { entry.restingHeartRate = rhr }
    if let avgHR = data.averageHeartRate { entry.averageHeartRate = avgHR }
}

private func applyScreenTimeData(from data: SnapshotData, to entry: DailyEntry) {
    if let seconds = data.screenTimeSeconds { entry.screenTimeSeconds = seconds }
    if let pickups = data.pickups { entry.pickups = pickups }
}
