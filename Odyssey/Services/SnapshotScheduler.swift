import BackgroundTasks
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SnapshotScheduler")

enum SnapshotScheduler {
    static func scheduleSnapshotTask() {
        // Cancel existing pending snapshot task
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.odyssey.snapshot")

        let request = BGAppRefreshTaskRequest(identifier: "com.odyssey.snapshot")
        let calendar = Calendar.current
        let now = Date()

        let modeRaw = UserDefaults.standard.string(forKey: "locationCaptureMode") ?? LocationCaptureMode.fixedTime.rawValue
        let mode = LocationCaptureMode(rawValue: modeRaw) ?? .fixedTime

        var targetHour: Int
        var targetMinute: Int

        switch mode {
        case .fixedTime:
            targetHour = UserDefaults.standard.object(forKey: "locationCaptureHour") as? Int ?? 20
            targetMinute = UserDefaults.standard.object(forKey: "locationCaptureMinute") as? Int ?? 0

        case .randomized:
            // Random minute offset between 480 (8 AM) and 1320 (10 PM)
            let totalMinutes = Int.random(in: 480...1320)
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
}
