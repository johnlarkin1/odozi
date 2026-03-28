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

            do {
                if let stepCount = try await stepsResult {
                    entry.stepCount = stepCount
                }
            } catch {
                logger.error("Steps fetch failed on Watch: \(error)")
            }

            do {
                if let walkingDistance = try await distanceResult {
                    entry.walkingDistanceMeters = walkingDistance
                }
            } catch {
                logger.error("Walking distance fetch failed on Watch: \(error)")
            }

            do {
                if let sleep = try await sleepResult {
                    if let totalHours = sleep.totalHours { entry.sleepHours = totalHours }
                    if let rem = sleep.remHours { entry.sleepREMHours = rem }
                    if let deep = sleep.deepHours { entry.sleepDeepHours = deep }
                    if let core = sleep.coreHours { entry.sleepCoreHours = core }
                    if let awake = sleep.awakeMinutes { entry.sleepAwakeMinutes = awake }
                    if let onset = sleep.sleepOnset { entry.sleepOnset = onset }
                    entry.sleepInterruptionCount = sleep.interruptionCount
                }
            } catch {
                logger.error("Sleep stages fetch failed on Watch: \(error)")
            }

            // Workout data — only set summary fields if encoding succeeds
            do {
                let workouts = try await workoutsResult
                if !workouts.isEmpty {
                    let encoded = try JSONEncoder().encode(workouts)
                    entry.workoutDataJSON = encoded
                    entry.workoutCount = workouts.count
                    entry.totalWorkoutMinutes = workouts.reduce(0) { $0 + $1.durationSeconds } / 60.0
                    entry.workoutIntensityScore = HealthKitService.computeIntensityScore(for: workouts)
                }
            } catch {
                logger.error("Workout fetch/encode failed on Watch: \(error)")
            }

            // Heart rate (now available on all platforms)
            do {
                if let avgHR = try await avgHRResult {
                    entry.averageHeartRate = avgHR
                }
            } catch {
                logger.error("Average heart rate fetch failed on Watch: \(error)")
            }

            do {
                if let restingHR = try await restingHRResult {
                    entry.restingHeartRate = restingHR
                }
            } catch {
                logger.error("Resting heart rate fetch failed on Watch: \(error)")
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
