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
            // Fetch all health metrics
            if let stepCount = try? await healthKit.fetchSteps(for: today) {
                entry.stepCount = stepCount
            }
            if let walkingDistance = try? await healthKit.fetchWalkingDistance(for: today) {
                entry.walkingDistanceMeters = walkingDistance
            }
            if let sleep = try? await healthKit.fetchSleepStages(for: today) {
                if let totalHours = sleep.totalHours { entry.sleepHours = totalHours }
                if let rem = sleep.remHours { entry.sleepREMHours = rem }
                if let deep = sleep.deepHours { entry.sleepDeepHours = deep }
                if let core = sleep.coreHours { entry.sleepCoreHours = core }
                if let awake = sleep.awakeMinutes { entry.sleepAwakeMinutes = awake }
                if let onset = sleep.sleepOnset { entry.sleepOnset = onset }
                entry.sleepInterruptionCount = sleep.interruptionCount
            }

            // Workout data
            if let workouts = try? await healthKit.fetchWorkouts(for: today), !workouts.isEmpty {
                entry.workoutDataJSON = try? JSONEncoder().encode(workouts)
                entry.workoutCount = workouts.count
                entry.totalWorkoutMinutes = workouts.reduce(0) { $0 + $1.durationSeconds } / 60.0
                entry.workoutIntensityScore = HealthKitService.computeIntensityScore(for: workouts)
            }

            // Heart rate (now available on all platforms)
            if let avgHR = try? await healthKit.fetchAverageHeartRate(for: today) {
                entry.averageHeartRate = avgHR
            }
            if let restingHR = try? await healthKit.fetchRestingHeartRate(for: today) {
                entry.restingHeartRate = restingHR
            }

            // Sleep score is computed by the main app during background snapshot
            // (requires SleepScoreService which lives in the Odyssey target)

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
}
