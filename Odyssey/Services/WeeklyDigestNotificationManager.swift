import UserNotifications
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WeeklyDigest")

enum WeeklyDigestNotificationManager {
    static let identifier = "weekly-digest"
    static let categoryIdentifier = "WEEKLY_DIGEST"

    // MARK: - Category Registration

    static func registerCategory() -> UNNotificationCategory {
        let openInsights = UNNotificationAction(
            identifier: "OPEN_JOURNAL",
            title: "Open Insights",
            options: [.foreground]
        )
        let startEntry = UNNotificationAction(
            identifier: "START_ENTRY",
            title: "Start Today's Entry",
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [openInsights, startEntry],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - Schedule

    static func schedule(weekday: Int = 1, hour: Int = 18, minute: Int = 0) {
        UserDefaults.standard.set(true, forKey: "weeklyDigestEnabled")
        UserDefaults.standard.set(weekday, forKey: "weeklyDigestWeekday")
        UserDefaults.standard.set(hour, forKey: "weeklyDigestHour")
        UserDefaults.standard.set(minute, forKey: "weeklyDigestMinute")

        Task {
            let granted = await NotificationService.requestAuthorization()
            guard granted else {
                logger.warning("Notification permission not granted — digest not scheduled")
                return
            }

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "Your Weekly Digest"
            content.body = "Tap to see how your week went."
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                logger.info("Scheduled weekly digest for weekday \(weekday) at \(hour):\(minute)")
            } catch {
                logger.error("Failed to schedule weekly digest: \(error)")
            }
        }
    }

    // MARK: - Refresh Content (called on foreground)

    @MainActor
    static func refreshContent(context: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: "weeklyDigestEnabled") else { return }

        let weekday = UserDefaults.standard.object(forKey: "weeklyDigestWeekday") as? Int ?? 1
        let hour = UserDefaults.standard.object(forKey: "weeklyDigestHour") as? Int ?? 18
        let minute = UserDefaults.standard.object(forKey: "weeklyDigestMinute") as? Int ?? 0

        let digest = WeeklyDigestService.computeDigest(context: context)

        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Digest"
        content.body = formatDigestBody(digest)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        // Render card image and attach
        if let imageURL = renderDigestCard(digest) {
            if let attachment = try? UNNotificationAttachment(
                identifier: "digest-card",
                url: imageURL,
                options: nil
            ) {
                content.attachments = [attachment]
            }
        }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        do {
            try await center.add(request)
            logger.info("Refreshed weekly digest content (\(digest.daysJournaled) days journaled)")
        } catch {
            logger.error("Failed to refresh weekly digest: \(error)")
        }
    }

    // MARK: - Cancel

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.set(false, forKey: "weeklyDigestEnabled")
        logger.info("Cancelled weekly digest")
    }

    // MARK: - Reschedule from persisted settings

    static func rescheduleIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "weeklyDigestEnabled") else { return }
        let weekday = UserDefaults.standard.object(forKey: "weeklyDigestWeekday") as? Int ?? 1
        let hour = UserDefaults.standard.object(forKey: "weeklyDigestHour") as? Int ?? 18
        let minute = UserDefaults.standard.object(forKey: "weeklyDigestMinute") as? Int ?? 0
        schedule(weekday: weekday, hour: hour, minute: minute)
    }

    // MARK: - Body Formatting

    static func formatDigestBody(_ data: WeeklyDigestData) -> String {
        guard data.hasData else {
            return "Start journaling this week! Open Odyssey to begin your first entry."
        }

        var lines: [String] = []

        lines.append("📓 \(data.daysJournaled)/\(data.totalDays) days journaled")

        let moodText = String(format: "%.1f/10", data.averageMood)
        if let delta = data.moodTrendDelta {
            let sign = delta >= 0 ? "+" : ""
            lines.append("😊 Avg mood: \(moodText) (\(sign)\(String(format: "%.1f", delta)) vs last week)")
        } else {
            lines.append("😊 Avg mood: \(moodText)")
        }

        if data.currentStreak > 0 {
            lines.append("🔥 \(data.currentStreak)-day streak")
        }

        if let emotion = data.topEmotion {
            lines.append("💭 Top feeling: \(emotion)")
        }

        return lines.joined(separator: "\n")
    }
}
