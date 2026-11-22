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

        // Everything below must happen on *every* launch, before this method returns — including
        // background relaunches, where the SwiftUI scene never becomes active and
        // `foregroundCatchUp` never runs.

        // HealthKit background delivery is routed to observer queries that exist at launch.
        // Observing needs only previously granted read access — it shows no UI.
        if HealthKitService.isAvailable, UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            Task {
                await HealthKitService.shared.startObserving()
            }
        }

        registerBackgroundTasks()
        // Only submit what isn't already pending: cancelling and resubmitting on every launch
        // pushed an overdue request back out (and re-rolled the randomized time).
        SnapshotScheduler.ensureScheduled()

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

    // MARK: - Retry when the device unlocks

    // A BGTask (or SLC/observer wake) that ran while the phone was locked can't read HealthKit —
    // captureHealthData skips it and marks "skipped-locked", and that run doesn't stamp the
    // debounce. When protected data becomes available, run one more capture to backfill. This
    // fires on every unlock, so it goes through the debounced shared path.
    func applicationProtectedDataDidBecomeAvailable(_: UIApplication) {
        Task {
            await BackgroundSnapshotService.captureAndApply(trigger: "protected-data-available")
        }
    }

    // MARK: - Background tasks

    /// Primary: a `BGAppRefreshTask` at the user's chosen capture time. Fallback: a
    /// `BGProcessingTask` early in the morning, after the phone is likely unlocked. Both run the
    /// same shared capture path as every other trigger.
    private func registerBackgroundTasks() {
        // `using: .main` so the launch handler runs on the main actor, where the capture lives.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: SnapshotScheduler.snapshotTaskID, using: .main) { task in
            MainActor.assumeIsolated {
                SnapshotScheduler.scheduleSnapshotTask()
                Self.run(task, trigger: "BGAppRefreshTask")
            }
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: SnapshotScheduler.processingTaskID, using: .main) { task in
            MainActor.assumeIsolated {
                SnapshotScheduler.scheduleProcessingTask()
                Self.run(task, trigger: "BGProcessingTask")
            }
        }
    }

    @MainActor
    private static func run(_ task: BGTask, trigger: String) {
        let completion = OneShotCompletion { task.setTaskCompleted(success: $0) }
        let work = Task { @MainActor in
            await BackgroundSnapshotService.captureAndApply(trigger: trigger, force: true)
            completion.complete(success: !Task.isCancelled)
        }
        task.expirationHandler = {
            logger.warning("\(trigger, privacy: .public) expired before the capture finished")
            work.cancel()
            completion.complete(success: false)
        }
    }
}

/// Delivers a completion exactly once. Used for `setTaskCompleted`: the work finishing and the
/// expiration handler (which may run on another thread) race; whichever comes first reports, the
/// other is a no-op.
final class OneShotCompletion: @unchecked Sendable {
    private let body: @Sendable (Bool) -> Void
    private let isDone = OSAllocatedUnfairLock(initialState: false)

    init(_ body: @escaping @Sendable (Bool) -> Void) {
        self.body = body
    }

    /// Returns whether this call delivered the completion.
    @discardableResult
    func complete(success: Bool) -> Bool {
        let isFirst = isDone.withLock { isDone in
            defer { isDone = true }
            return !isDone
        }
        if isFirst {
            body(success)
        }
        return isFirst
    }
}
