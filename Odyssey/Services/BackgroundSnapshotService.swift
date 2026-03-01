import SwiftData
import Foundation
import os

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

        return SnapshotData(
            latitude: location?.latitude,
            longitude: location?.longitude,
            city: location?.city,
            state: location?.state,
            country: location?.country,
            stepCount: health.steps,
            walkingDistanceMeters: health.distance,
            sleepHours: health.sleep,
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

@MainActor
func applySnapshotData(_ data: SnapshotData, to context: ModelContext) {
    let today = Calendar.current.startOfDay(for: Date())
    let predicate = #Predicate<DailyEntry> { $0.date == today }
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1

    let entry: DailyEntry
    if let existing = try? context.fetch(descriptor).first {
        entry = existing
    } else {
        entry = DailyEntry(date: today)
        context.insert(entry)
    }

    // Apply location data
    if let lat = data.latitude { entry.latitude = lat }
    if let lon = data.longitude { entry.longitude = lon }
    if let city = data.city { entry.city = city }
    if let state = data.state { entry.state = state }
    if let country = data.country { entry.country = country }

    // Apply HealthKit data
    if let steps = data.stepCount { entry.stepCount = steps }
    if let distance = data.walkingDistanceMeters { entry.walkingDistanceMeters = distance }
    if let sleep = data.sleepHours { entry.sleepHours = sleep }

    // Apply Screen Time data
    if let seconds = data.screenTimeSeconds { entry.screenTimeSeconds = seconds }
    if let pickups = data.pickups { entry.pickups = pickups }

    entry.updatedAt = Date()
    entry.needsSync = true

    do {
        try context.save()
    } catch {
        logger.error("Failed to save snapshot: \(error)")
    }
}
