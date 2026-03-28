import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchHealth")

@MainActor
struct WatchHealthCapture {
    let modelContext: ModelContext
    private let healthKit = HealthKitService()

    func requestAuthorization() async {
        do {
            try await healthKit.requestAuthorization()
        } catch {
            logger.error("HealthKit authorization failed: \(error)")
        }
    }

    func captureHealthData() async {
        let today = Date()
        let repo = DailyEntryRepository(context: modelContext)

        guard let entry = try? repo.fetchOrCreateToday() else {
            logger.error("Failed to fetch or create today's entry")
            return
        }

        do {
            // Fetch health metrics concurrently to avoid watchOS background task timeouts
            async let stepsResult = healthKit.fetchSteps(for: today)
            async let distanceResult = healthKit.fetchWalkingDistance(for: today)
            async let sleepResult = healthKit.fetchSleepStages(for: today)
            async let workoutsResult = healthKit.fetchWorkouts(for: today)
            async let avgHRResult = healthKit.fetchAverageHeartRate(for: today)
            async let restingHRResult = healthKit.fetchRestingHeartRate(for: today)

            applyBasicMetrics(stepsResult: try await stepsResult, distanceResult: try await distanceResult, to: entry)
            applySleepData(try await sleepResult, to: entry)
            applyWorkoutData(try await workoutsResult, to: entry)
            applyHeartRateData(avgHR: try await avgHRResult, restingHR: try await restingHRResult, to: entry)

            entry.updatedAt = Date()
            entry.needsSync = true
            try modelContext.save()

            logger
                .info(
                    "Health data captured: steps=\(entry.stepCount ?? 0), sleep=\(entry.sleepHours ?? 0), score=\(entry.sleepScore ?? 0), workouts=\(entry.workoutCount ?? 0)"
                )
        } catch {
            logger.error("Failed to capture health data: \(error)")
        }
    }

    private func applyBasicMetrics(stepsResult: Int?, distanceResult: Double?, to entry: DailyEntry) {
        if let stepCount = stepsResult { entry.stepCount = stepCount }
        if let distance = distanceResult { entry.walkingDistanceMeters = distance }
    }

    private func applySleepData(_ sleep: SleepStageData?, to entry: DailyEntry) {
        guard let sleep else { return }
        if let totalHours = sleep.totalHours { entry.sleepHours = totalHours }
        if let rem = sleep.remHours { entry.sleepREMHours = rem }
        if let deep = sleep.deepHours { entry.sleepDeepHours = deep }
        if let core = sleep.coreHours { entry.sleepCoreHours = core }
        if let awake = sleep.awakeMinutes { entry.sleepAwakeMinutes = awake }
        if let onset = sleep.sleepOnset { entry.sleepOnset = onset }
        entry.sleepInterruptionCount = sleep.interruptionCount
    }

    private func applyWorkoutData(_ workouts: [WorkoutSummary], to entry: DailyEntry) {
        guard !workouts.isEmpty else { return }
        do {
            let encoded = try JSONEncoder().encode(workouts)
            entry.workoutDataJSON = encoded
            entry.workoutCount = workouts.count
            entry.totalWorkoutMinutes = workouts.reduce(0) { $0 + $1.durationSeconds } / 60.0
            entry.workoutIntensityScore = HealthKitService.computeIntensityScore(for: workouts)
        } catch {
            logger.error("Workout encode failed on Watch: \(error)")
        }
    }

    private func applyHeartRateData(avgHR: Double?, restingHR: Double?, to entry: DailyEntry) {
        if let avgHR { entry.averageHeartRate = avgHR }
        if let restingHR { entry.restingHeartRate = restingHR }
    }
}
