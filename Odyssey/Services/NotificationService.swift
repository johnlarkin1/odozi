import UserNotifications
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Notifications")

enum NotificationService {
    private static let reminderID = "daily-journal-reminder"

    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Notification authorization: \(granted)")
            return granted
        } catch {
            logger.error("Notification authorization failed: \(error)")
            return false
        }
    }

    static func scheduleReminder(timeOfDay: ReminderTimeOfDay, customHour: Int = 20, customMinute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let content = UNMutableNotificationContent()
        content.title = "Time to Journal"
        content.body = timeOfDay.notificationBody
        content.sound = .default

        let hour: Int
        let minute: Int
        if timeOfDay == .custom {
            hour = customHour
            minute = customMinute
        } else {
            hour = timeOfDay.hour
            minute = 0
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                logger.error("Failed to schedule reminder: \(error)")
            } else {
                logger.info("Scheduled daily reminder at \(hour):\(minute)")
            }
        }

        // Persist preference
        UserDefaults.standard.set(true, forKey: "reminderEnabled")
        UserDefaults.standard.set(timeOfDay.rawValue, forKey: "reminderTimeOfDay")
        UserDefaults.standard.set(customHour, forKey: "reminderCustomHour")
        UserDefaults.standard.set(customMinute, forKey: "reminderCustomMinute")
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
        UserDefaults.standard.set(false, forKey: "reminderEnabled")
        logger.info("Cancelled daily reminder")
    }

    static func rescheduleIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else { return }
        let rawValue = UserDefaults.standard.string(forKey: "reminderTimeOfDay") ?? ReminderTimeOfDay.evening.rawValue
        let timeOfDay = ReminderTimeOfDay(rawValue: rawValue) ?? .evening
        let customHour = UserDefaults.standard.object(forKey: "reminderCustomHour") as? Int ?? 20
        let customMinute = UserDefaults.standard.object(forKey: "reminderCustomMinute") as? Int ?? 0
        scheduleReminder(timeOfDay: timeOfDay, customHour: customHour, customMinute: customMinute)
    }

    static func cancelTodaysPendingReminder() {
        // Remove the pending notification so the user isn't reminded after they already journaled
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
        // Reschedule for tomorrow by re-adding the repeating trigger
        rescheduleIfNeeded()
    }
}
