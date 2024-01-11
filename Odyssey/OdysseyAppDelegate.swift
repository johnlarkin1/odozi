//
//  OdysseyAppDelegate.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import Foundation
import BackgroundTasks
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    let persistenceController = PersistenceController.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.odyssey.refresh", using: nil) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule a new refresh task
        scheduleAppRefresh()
        
        // Create an operation that performs the main part of the background task
        let context = persistenceController.container.viewContext
        let operation = BackgroundDataFetch(context: context)
        
        // Provide an expiration handler for the background task
        task.expirationHandler = {
            operation.cancel()
        }
        
        // Inform the system that the background task is complete
        // when the operation is done
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        // Start the operation
        let operationQueue = OperationQueue()
        operationQueue.addOperation(operation)
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.odyssey.refresh")

        // Calculate time until 11:55 PM today or tomorrow
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current // Use the device's time zone
        let elevenFiftyFiveToday = calendar.date(
            bySettingHour: 23, minute: 55, second: 0, of: now)!
        let timeUntilElevenFiftyFive = elevenFiftyFiveToday.timeIntervalSince(now)
        
        // If it's past 11:55 PM, schedule for the next day
        if timeUntilElevenFiftyFive < 0 {
            if let elevenFiftyFiveTomorrow = calendar.date(byAdding: .day, value: 1, to: elevenFiftyFiveToday) {
                request.earliestBeginDate = elevenFiftyFiveTomorrow
            }
        } else {
            request.earliestBeginDate = elevenFiftyFiveToday
        }

        // Submit the request
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
