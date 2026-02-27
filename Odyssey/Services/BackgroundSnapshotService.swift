import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "BackgroundSnapshot")

actor BackgroundSnapshotService {
    private let locationService = LocationCaptureService()
    private let healthKitService = HealthKitService()

    func captureSnapshot(modelContext: ModelContext) async {
        let today = Calendar.current.startOfDay(for: Date())
        let entry = fetchOrCreateEntry(for: today, in: modelContext)

        // Run location and HealthKit concurrently
        async let locationResult = captureLocation()
        async let healthResult = captureHealthData(for: today)
        let screenTimeResult = readScreenTimeFromDefaults()

        let location = await locationResult
        let health = await healthResult

        // Apply location data
        if let loc = location {
            entry.latitude = loc.latitude
            entry.longitude = loc.longitude
            entry.city = loc.city
            entry.state = loc.state
            entry.country = loc.country
        }

        // Apply HealthKit data
        if let steps = health.steps { entry.stepCount = steps }
        if let distance = health.distance { entry.walkingDistanceMeters = distance }
        if let sleep = health.sleep { entry.sleepHours = sleep }

        // Apply Screen Time data
        if let st = screenTimeResult {
            entry.screenTimeSeconds = st.seconds
            entry.pickups = st.pickups
        }

        entry.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save snapshot: \(error)")
        }
    }

    private func fetchOrCreateEntry(for date: Date, in context: ModelContext) -> DailyEntry {
        let predicate = #Predicate<DailyEntry> { $0.date == date }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let entry = DailyEntry(date: date)
        context.insert(entry)
        return entry
    }

    private func captureLocation() async -> LocationSnapshot? {
        do {
            return try await locationService.captureCurrentLocation()
        } catch {
            logger.error("Location capture failed: \(error)")
            return nil
        }
    }

    private func captureHealthData(for date: Date) async -> (steps: Int?, distance: Double?, sleep: Double?) {
        guard HealthKitService.isAvailable else {
            return (nil, nil, nil)
        }

        async let steps = try? healthKitService.fetchSteps(for: date)
        async let distance = try? healthKitService.fetchWalkingDistance(for: date)
        async let sleep = try? healthKitService.fetchSleepHours(for: date)

        return await (steps, distance, sleep)
    }

    private func readScreenTimeFromDefaults() -> (seconds: Double, pickups: Int)? {
        SharedDefaults.getScreenTime()
    }
}
