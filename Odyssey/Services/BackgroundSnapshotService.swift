import CoreLocation
import Foundation
import os
import SwiftData
#if canImport(UIKit)
    import UIKit
#endif

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "BackgroundSnapshot")

struct SnapshotData: Sendable {
    /// The journal day this snapshot belongs to. Fixed when the capture starts, so a run that
    /// straddles midnight queries and writes one day consistently.
    let day: Date
    let location: LocationSnapshot?
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
    /// HealthKit was skipped because the device was locked (its data is encrypted at rest).
    let healthSkippedLocked: Bool
    let screenTimeSeconds: Double?
    let pickups: Int?
}

#if canImport(UIKit)
    /// A UIKit background-task assertion: asks iOS for extra time to finish (and save) work that
    /// started while the app was being woken in — or sent to — the background. Without one, the
    /// process can be suspended between the capture and the SwiftData save.
    @MainActor
    final class BackgroundTaskAssertion {
        private var identifier: UIBackgroundTaskIdentifier = .invalid

        init(name: String) {
            identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
                MainActor.assumeIsolated { self?.end() }
            }
        }

        /// Idempotent. Must be called when the work finishes, or iOS terminates the app.
        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
#endif

/// Coalesces concurrent capture triggers into one run at a time. Pure coordination with no I/O,
/// so the join / re-run / debounce rules are unit-testable with a fake operation.
///
/// Rules:
/// - A caller that arrives while a run is in flight joins it instead of starting another.
/// - Joining is enough, unless the caller is forced (the user is waiting) and the run it joined
///   can't stand in for one: a background-triggered run, which may have started before the scene
///   was active, or a run cut short by cancellation (e.g. a BGTask expiring). Then it runs again.
/// - A non-forced caller is skipped when `isDebounced` says so. The check and the start happen
///   on the main actor with no suspension between them, so the gate is atomic.
@MainActor
final class CaptureCoordinator {
    enum Outcome: Equatable {
        case ran, joined, debounced
    }

    private struct Run {
        let id: Int
        let task: Task<Void, Never>
        let isForced: Bool
    }

    private var current: Run?
    private var nextRunID = 0

    var isRunning: Bool {
        current != nil
    }

    func run(
        force: Bool,
        isDebounced: () -> Bool,
        operation: @escaping @MainActor () async -> Void
    ) async -> Outcome {
        while let running = current {
            await running.task.value
            let stoodIn = running.isForced && !running.task.isCancelled
            guard force, !Task.isCancelled, !stoodIn else { return .joined }
            // Otherwise loop: join whatever started meanwhile, or fall through and run.
        }

        if !force, isDebounced() {
            return .debounced
        }

        nextRunID += 1
        let id = nextRunID
        let task = Task { @MainActor in
            await operation()
            // Free the slot from inside the run, before it completes. Anyone awaiting
            // `task.value` then already sees it free; clearing it in the awaiting owner raced
            // the joiners, which usually resumed first and saw a stale run.
            if self.current?.id == id {
                self.current = nil
            }
        }
        current = Run(id: id, task: task, isForced: force)

        // This caller's cancellation (e.g. its BGTask expiring) stops the shared run; forced
        // joiners notice the cancellation and run again.
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        return .ran
    }
}

actor BackgroundSnapshotService {
    // The same instance the observer queries and background delivery are registered on.
    private let healthKitService = HealthKitService.shared

    /// Minimum gap between background-triggered captures. Significant-location-change deliveries
    /// arrive in bursts while travelling, the six HealthKit observer queries can all fire at once
    /// when a workout syncs, and protected-data-available fires on every unlock — without this,
    /// each of those runs a full capture for values that change slowly.
    static let backgroundCaptureInterval: TimeInterval = 60 * 60

    /// Coalesces concurrent triggers into one capture at a time (see `CaptureCoordinator`).
    @MainActor private static let coordinator = CaptureCoordinator()

    // MARK: - Entry points

    /// The single path every trigger uses — foreground, BGTasks, SLC wakes, HealthKit observers and
    /// the unlock retry: capture a snapshot and apply it to today's entry. `applySnapshotData` only
    /// writes non-nil values, so repeated runs are safe.
    ///
    /// - Parameters:
    ///   - trigger: what woke us, for the log line.
    ///   - force: skip the debounce. Used by the foreground and BGTask paths, which the OS already
    ///     rate-limits and which the user is actually waiting on. A forced call still joins a
    ///     capture that's already in flight rather than duplicating it.
    @MainActor
    static func captureAndApply(trigger: String, force: Bool = false) async {
        // Held while joining too: a caller waiting on someone else's run still needs the app awake.
        #if canImport(UIKit)
            let assertion = BackgroundTaskAssertion(name: "snapshot")
            defer { assertion.end() }
        #endif

        let outcome = await coordinator.run(
            force: force,
            isDebounced: { isDebounced(trigger: trigger) },
            operation: { await runCapture(trigger: trigger) }
        )
        if outcome == .joined {
            logger.info("\(trigger, privacy: .public) joined the capture already in flight")
        }
    }

    @MainActor
    private static func isDebounced(trigger: String) -> Bool {
        guard let last = SharedDefaults.lastCaptureRunDate else { return false }
        let age = Date().timeIntervalSince(last)
        guard age < backgroundCaptureInterval else { return false }
        logger.info("Skipping \(trigger, privacy: .public) capture — last run \(Int(age))s ago")
        return true
    }

    /// Whether a finished run starts the debounce window. Not when HealthKit was skipped because
    /// the phone was locked, nor when a BGTask expiring cut the run short — otherwise the triggers
    /// that would complete it (the unlock retry, the next wake) are debounced away for an hour.
    static func shouldStampDebounce(healthSkippedLocked: Bool, wasCancelled: Bool) -> Bool {
        !healthSkippedLocked && !wasCancelled
    }

    /// Called synchronously from the significant-location-change delegate callback with the fix
    /// iOS delivered. Saves that fix's coordinates straight away — a wake only gets a few seconds,
    /// and coordinates are what matter; the place name can be filled in later — then runs the
    /// usual (debounced) capture for everything else, which also names the coordinates.
    @MainActor
    static func handleSignificantLocationChange(_ fix: CLLocation) {
        #if canImport(UIKit)
            let assertion = BackgroundTaskAssertion(name: "slc-capture")
        #endif
        Task { @MainActor in
            #if canImport(UIKit)
                defer { assertion.end() }
            #endif
            let saved = recordCoordinates(of: fix)
            if saved {
                // Name the coordinates now rather than waiting out the debounce.
                await fillMissingPlace(day: Calendar.current.startOfDay(for: fix.timestamp))
                NotificationCenter.default.post(name: .snapshotDidUpdate, object: nil)
            }
            await captureAndApply(trigger: "significant-location-change")
        }
    }

    // MARK: - Capture pipeline

    @MainActor
    private static func runCapture(trigger: String) async {
        do {
            let context = try DataContainer.shared().mainContext
            let day = Calendar.current.startOfDay(for: Date())

            // Coordinates saved by an earlier wake that was suspended mid-geocode get named here.
            await fillMissingPlace(day: day)

            // Only ask CoreLocation for a live fix when today has no location yet. The day's first
            // location sticks, so re-requesting on every foreground just burns battery and
            // geocoder quota.
            let hasLocation = try DailyEntryRepository(context: context).fetchEntry(for: day)?.latitude != nil
            let data = await BackgroundSnapshotService().captureSnapshot(day: day, includeLocation: !hasLocation)

            guard applySnapshotData(data, to: context) else { return }

            if shouldStampDebounce(healthSkippedLocked: data.healthSkippedLocked, wasCancelled: Task.isCancelled) {
                SharedDefaults.markCaptureRun()
            }
            NotificationCenter.default.post(name: .snapshotDidUpdate, object: nil)
            logger.info("Applied snapshot from \(trigger, privacy: .public)")
        } catch {
            logger.error("Snapshot from \(trigger, privacy: .public) failed: \(error)")
        }
    }

    /// Writes `fix`'s coordinates to its day's entry if that day has no location yet.
    /// Returns whether anything was saved.
    @MainActor
    private static func recordCoordinates(of fix: CLLocation) -> Bool {
        do {
            let context = try DataContainer.shared().mainContext
            let entry = try DailyEntryRepository(context: context).fetchOrCreate(for: fix.timestamp)
            let snapshot = LocationSnapshot(
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude,
                city: nil, state: nil, country: nil,
                timestamp: fix.timestamp
            )
            // fetchOrCreate only inserts when the day has no entry, and then applyLocation always
            // writes — so a `false` here never leaves an empty row behind.
            guard applyLocation(snapshot, to: entry) else { return false }
            entry.updatedAt = Date()
            try context.save()
            SharedDefaults.setLocationCaptureOutcome("ok slc")
            logger.info("Saved SLC coordinates for today")
            return true
        } catch {
            logger.error("Failed to save SLC coordinates: \(error)")
            return false
        }
    }

    /// If `day`'s entry has coordinates but was never named (e.g. iOS suspended a wake mid-geocode,
    /// or the network was down), reverse-geocode and fill them in. "Never named" means no place
    /// field at all: a place can legitimately have no city (rural areas, parks, at sea), and
    /// treating that as unnamed would re-geocode on every trigger for the rest of the day.
    @MainActor
    private static func fillMissingPlace(day: Date) async {
        do {
            let context = try DataContainer.shared().mainContext
            guard let entry = try DailyEntryRepository(context: context).fetchEntry(for: day),
                  entry.city == nil, entry.state == nil, entry.country == nil,
                  let latitude = entry.latitude,
                  let longitude = entry.longitude
            else { return }

            let location = CLLocation(latitude: latitude, longitude: longitude)
            guard let place = await PlaceResolver.place(for: location) else { return }
            // The entry may have been edited while we were geocoding — only name the same point.
            guard entry.city == nil, entry.state == nil, entry.country == nil,
                  entry.latitude == latitude, entry.longitude == longitude else { return }
            entry.city = place.city
            entry.state = place.state
            entry.country = place.country
            try context.save()
        } catch {
            logger.error("Failed to fill in place name: \(error)")
        }
    }

    func captureSnapshot(day: Date? = nil, includeLocation: Bool = true) async -> SnapshotData {
        let day = day ?? Calendar.current.startOfDay(for: Date())

        // Run location and HealthKit concurrently
        async let locationResult = captureLocation(if: includeLocation)
        async let healthResult = captureHealthData(for: day)
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
                logger.info("Encoded \(health.workouts.count) workouts")
            } catch {
                logger.error("Failed to encode workout data: \(error)")
            }
        }

        return SnapshotData(
            day: day,
            location: location,
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
            healthSkippedLocked: health.skippedLocked,
            screenTimeSeconds: screenTimeResult?.seconds,
            pickups: screenTimeResult?.pickups
        )
    }

    private func captureLocation(if include: Bool) async -> LocationSnapshot? {
        guard include else { return nil }
        do {
            let service = await LocationCaptureService()
            let snapshot = try await service.captureCurrentLocation()
            SharedDefaults.setLocationCaptureOutcome("ok \(snapshot.city ?? "?")")
            return snapshot
        } catch let error as LocationCaptureError {
            switch error {
            case .permissionDenied:
                SharedDefaults.setLocationCaptureOutcome("denied")
            case .permissionNotDetermined:
                SharedDefaults.setLocationCaptureOutcome("notDetermined")
            case .needsAlwaysAuthorization:
                SharedDefaults.setLocationCaptureOutcome("needsAlways")
            case .locationUnavailable:
                SharedDefaults.setLocationCaptureOutcome("unavailable")
            }
            logger.error("Location capture failed: \(error)")
            return nil
        } catch {
            SharedDefaults.setLocationCaptureOutcome("error")
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
        var skippedLocked = false

        static let empty = HealthData(
            steps: nil, distance: nil, sleep: nil, workouts: [], restingHeartRate: nil, averageHeartRate: nil
        )
    }

    private func captureHealthData(for date: Date) async -> HealthData {
        guard HealthKitService.isAvailable else {
            SharedDefaults.setHealthCaptureOutcome("unavailable")
            return .empty
        }

        // HealthKit is encrypted while the device is locked; querying then just fails silently
        // (a common cause of empty background captures, e.g. an overnight task on a locked phone).
        // Skip cleanly and let the protected-data-available retry fill it in later.
        guard await Self.isProtectedDataAvailable() else {
            logger.warning("Protected data unavailable (device locked) — skipping HealthKit capture")
            SharedDefaults.setHealthCaptureOutcome("skipped-locked")
            var skipped = HealthData.empty
            skipped.skippedLocked = true
            return skipped
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

        let capturedAny = steps != nil || distance != nil || sleep != nil
            || !workouts.isEmpty || restingHR != nil || averageHR != nil
        SharedDefaults.setHealthCaptureOutcome(capturedAny ? "ok" : "empty")

        return HealthData(
            steps: steps, distance: distance, sleep: sleep,
            workouts: workouts, restingHeartRate: restingHR, averageHeartRate: averageHR
        )
    }

    /// Whether HealthKit-protected data is currently readable (device unlocked at least once).
    /// Checked on the main actor since `UIApplication` is main-actor isolated.
    private static func isProtectedDataAvailable() async -> Bool {
        #if canImport(UIKit)
            return await MainActor.run { UIApplication.shared.isProtectedDataAvailable }
        #else
            return true
        #endif
    }

    private func readScreenTimeFromDefaults() -> (seconds: Double, pickups: Int)? {
        SharedDefaults.getScreenTime()
    }
}

/// Applies a snapshot to its day's entry and saves. Returns whether the save succeeded.
@MainActor
@discardableResult
func applySnapshotData(_ data: SnapshotData, to context: ModelContext) -> Bool {
    let repository = DailyEntryRepository(context: context)

    do {
        let entry = try repository.fetchOrCreate(for: data.day)

        // A fix from a different day (e.g. a cached one across midnight) must not label this entry.
        if let location = data.location,
           Calendar.current.isDate(location.timestamp, inSameDayAs: data.day) {
            applyLocation(location, to: entry)
        }
        applyHealthKitData(from: data, to: entry)
        try applySleepScore(for: entry, data: data, context: context)
        applyWorkoutAndHeartRateData(from: data, to: entry)
        applyScreenTimeData(from: data, to: entry)

        entry.updatedAt = Date()

        try context.save()
        return true
    } catch {
        logger.error("Failed to save snapshot: \(error)")
        return false
    }
}

/// Writes a location to `entry` as one unit — coordinates, place name and the fix's own timestamp
/// together, never a mix of fields from different fixes. The day's first location sticks (a later
/// passive capture doesn't move it); the one exception is the same coordinates coming back with a
/// place name, after an earlier geocode failed. Manual "update location" actions bypass this.
///
/// Returns whether anything changed.
@MainActor
@discardableResult
func applyLocation(_ location: LocationSnapshot, to entry: DailyEntry) -> Bool {
    if entry.latitude == nil || entry.longitude == nil {
        entry.latitude = location.latitude
        entry.longitude = location.longitude
        entry.city = location.city
        entry.state = location.state
        entry.country = location.country
        entry.locationCapturedAt = location.timestamp
        return true
    }

    if entry.city == nil, location.city != nil,
       entry.latitude == location.latitude, entry.longitude == location.longitude {
        entry.city = location.city
        entry.state = location.state
        entry.country = location.country
        return true
    }

    return false
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
