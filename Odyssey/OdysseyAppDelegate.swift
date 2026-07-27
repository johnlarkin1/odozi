import BackgroundTasks
import Foundation
import os
import SwiftData
import UIKit
import UserNotifications

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "BackgroundTasks")

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register notification categories and delegate
        NotificationService.registerAllCategories()
        UNUserNotificationCenter.current().delegate = self

        // Register primary snapshot task (user-chosen capture time)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.odyssey.snapshot", using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleSnapshot(task: refreshTask)
        }

        // Register fallback processing task (early morning, after the phone is likely unlocked)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.odyssey.processing", using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleProcessing(task: processingTask)
        }

        scheduleSnapshotTask()
        scheduleProcessingTask()

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        if categoryIdentifier == WeeklyDigestNotificationManager.categoryIdentifier {
            Task { @MainActor in
                switch response.actionIdentifier {
                case "START_ENTRY":
                    DeepLinkRouter.navigate(to: .guidedPrompt)
                case "OPEN_INSIGHTS", UNNotificationDefaultActionIdentifier:
                    DeepLinkRouter.navigate(to: .weeklyReport)
                default:
                    break
                }
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Primary: BGAppRefreshTask at 8 PM

    private func handleSnapshot(task: BGAppRefreshTask) {
        scheduleSnapshotTask()

        let snapshotTask = Task {
            do {
                let container = try DataContainer.create()
                let service = BackgroundSnapshotService()
                let data = await service.captureSnapshot()
                await MainActor.run {
                    applySnapshotData(data, to: container.mainContext)
                }
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Snapshot task failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            snapshotTask.cancel()
        }
    }

    private func scheduleSnapshotTask() {
        SnapshotScheduler.scheduleSnapshotTask()
    }

    // MARK: - Retry when the device unlocks

    // A BGTask (or SLC/observer wake) that ran while the phone was locked can't read HealthKit —
    // captureHealthData skips it and marks "skipped-locked". When protected data becomes
    // available, run one more capture to backfill. applySnapshotData only writes non-nil values,
    // so this is safe and idempotent.
    func applicationProtectedDataDidBecomeAvailable(_: UIApplication) {
        logger.info("Protected data available — running catch-up snapshot")
        Task {
            do {
                let container = try DataContainer.create()
                let service = BackgroundSnapshotService()
                let data = await service.captureSnapshot()
                await MainActor.run {
                    applySnapshotData(data, to: container.mainContext)
                }
            } catch {
                logger.error("Protected-data catch-up snapshot failed: \(error)")
            }
        }
    }

    // MARK: - Fallback: BGProcessingTask (early morning)

    private func handleProcessing(task: BGProcessingTask) {
        scheduleProcessingTask()

        let processingTask = Task {
            do {
                let container = try DataContainer.create()
                let service = BackgroundSnapshotService()
                let data = await service.captureSnapshot()
                await MainActor.run {
                    applySnapshotData(data, to: container.mainContext)
                }
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Processing task failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            processingTask.cancel()
        }
    }

    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.odyssey.processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        let calendar = Calendar.current
        let now = Date()
        // 7 AM: late enough that the phone has usually been unlocked at least once (so HealthKit
        // is readable), while still an idle window iOS is willing to schedule processing tasks in.
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
        } catch {
            logger.error("Could not schedule processing task: \(error)")
        }
    }
}
