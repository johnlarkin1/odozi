import Foundation
import SwiftData
import os

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

        // Fetch all health metrics concurrently
        async let steps = healthKit.fetchSteps(for: today)
        async let distance = healthKit.fetchWalkingDistance(for: today)
        async let sleep = healthKit.fetchSleepHours(for: today)
        #if os(watchOS)
        async let heartRate = healthKit.fetchAverageHeartRate(for: today)
        #endif

        do {
            if let stepCount = try await steps {
                entry.stepCount = stepCount
            }
            if let walkingDistance = try await distance {
                entry.walkingDistanceMeters = walkingDistance
            }
            if let sleepHours = try await sleep {
                entry.sleepHours = sleepHours
            }

            entry.updatedAt = Date()
            entry.needsSync = true
            try modelContext.save()

            logger.info("Health data captured: steps=\(entry.stepCount ?? 0), sleep=\(entry.sleepHours ?? 0)")
        } catch {
            logger.error("Failed to capture health data: \(error)")
        }
    }
}
