import BackgroundTasks
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SnapshotScheduler")

enum SnapshotScheduler {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let snapshotTaskID = "com.odyssey.snapshot"
    static let processingTaskID = "com.odyssey.processing"

    /// Submits whichever background tasks aren't already pending. Called on every launch, so it
    /// must not disturb a pending request: unconditionally cancelling and resubmitting pushed an
    /// overdue request back out to tomorrow every time the app launched, and re-rolled the
    /// randomized capture time.
    static func ensureScheduled() {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let pending = Set(requests.map(\.identifier))
            if !pending.contains(snapshotTaskID) {
                scheduleSnapshotTask()
            }
            if !pending.contains(processingTaskID) {
                scheduleProcessingTask()
            }
        }
    }

    /// (Re)schedules the primary capture at the user's chosen time. Replaces any pending request —
    /// call it when that time changes and from the task handler, not on every launch.
    static func scheduleSnapshotTask() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: snapshotTaskID)

        let request = BGAppRefreshTaskRequest(identifier: snapshotTaskID)
        let calendar = Calendar.current
        let now = Date()

        let modeRaw = UserDefaults.standard.string(forKey: "locationCaptureMode") ?? LocationCaptureMode.evening.rawValue
        let mode = LocationCaptureMode(rawValue: modeRaw) ?? .evening

        var targetHour: Int
        var targetMinute: Int

        switch mode {
        case .morning, .afternoon, .evening:
            targetHour = mode.hour
            targetMinute = 0

        case .custom:
            // Read stored hour/minute from UserDefaults
            targetHour = UserDefaults.standard.object(forKey: "locationCaptureHour") as? Int ?? 20
            targetMinute = UserDefaults.standard.object(forKey: "locationCaptureMinute") as? Int ?? 0

        case .randomized:
            // Random minute offset between 480 (8 AM) and 1320 (10 PM)
            let totalMinutes = Int.random(in: 480 ... 1320)
            targetHour = totalMinutes / 60
            targetMinute = totalMinutes % 60
        }

        guard var target = calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: now) else {
            logger.warning("Failed to compute snapshot target date")
            return
        }

        if target <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: target) else { return }
            target = next
        }

        request.earliestBeginDate = target

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled snapshot task for \(target, privacy: .public) (mode: \(modeRaw, privacy: .public))")
        } catch {
            logger.error("Could not schedule snapshot task: \(error)")
        }
    }

    /// Fallback capture at 7 AM: late enough that the phone has usually been unlocked at least
    /// once (so HealthKit is readable), while still an idle window iOS will run processing tasks in.
    static func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: processingTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        let calendar = Calendar.current
        let now = Date()
        guard var target = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) else {
            logger.warning("Failed to compute processing target date")
            return
        }
        if target <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: target) else { return }
            target = next
        }
        request.earliestBeginDate = target

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled processing task for \(target, privacy: .public)")
        } catch {
            logger.error("Could not schedule processing task: \(error)")
        }
    }
}
