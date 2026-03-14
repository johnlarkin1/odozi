import Foundation
import BackgroundTasks
import UIKit
import SwiftData
import UserNotifications
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "BackgroundTasks")

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register notification categories and delegate
        NotificationService.registerAllCategories()
        UNUserNotificationCenter.current().delegate = self

        // Register primary snapshot task (8 PM)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.odyssey.snapshot", using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleSnapshot(task: refreshTask)
        }

        // Register fallback processing task (2 AM)
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
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        if categoryIdentifier == WeeklyDigestNotificationManager.categoryIdentifier {
            switch response.actionIdentifier {
            case "START_ENTRY":
                NavigationState.shared.selectedTab = .today
                NavigationState.shared.showGuidedPrompt = true
            case "OPEN_JOURNAL", UNNotificationDefaultActionIdentifier:
                NavigationState.shared.selectedTab = .insights
            default:
                break
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
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

    // MARK: - Fallback: BGProcessingTask at 2 AM

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
        guard var target = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: now) else {
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
