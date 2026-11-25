import DeviceActivity
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DeviceActivityMonitor")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let suiteName = "group.com.johnlarkin.Odyssey"

    private var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // Keys — must match SharedDefaults in the main app
    private let screenTimeSecondsKey = "screenTimeSeconds"
    private let screenTimeLastUpdatedKey = "screenTimeLastUpdated"
    private let maxThresholdMinutesKey = "screenTimeMaxThresholdMinutes"
    private let intervalDateKey = "screenTimeIntervalDate"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.info("intervalDidStart: \(activity.rawValue)")

        guard let defaults = suite else {
            logger.error("App Group UserDefaults unavailable")
            return
        }

        // Reset the counters only when a new day starts. The system also delivers
        // intervalDidStart when monitoring is (re)started mid-day, and wiping here
        // then would throw away the screen time already captured today.
        resetIfNewDay(defaults)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.info("eventDidReachThreshold: \(event.rawValue) for \(activity.rawValue)")

        guard let defaults = suite else {
            logger.error("App Group UserDefaults unavailable")
            return
        }

        guard let minutes = Self.parseThresholdMinutes(from: event) else {
            logger.warning("Could not parse threshold from event: \(event.rawValue)")
            return
        }

        // Midnight safety net: if today's intervalDidStart never arrived, yesterday's max
        // would otherwise block every threshold today.
        resetIfNewDay(defaults)

        // Dedup: only update if this threshold is higher than previous max
        let currentMax = defaults.integer(forKey: maxThresholdMinutesKey)
        guard minutes > currentMax else {
            logger.info("Ignoring duplicate/lower threshold \(minutes)m (current max: \(currentMax)m)")
            return
        }

        let seconds = Double(minutes * 60)
        defaults.set(seconds, forKey: screenTimeSecondsKey)
        defaults.set(minutes, forKey: maxThresholdMinutesKey)
        defaults.set(Date().timeIntervalSince1970, forKey: screenTimeLastUpdatedKey)

        logger.info("Updated screen time: \(seconds)s (threshold: \(minutes)m)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("intervalDidEnd: \(activity.rawValue)")
    }

    // MARK: - Helpers

    /// Zeroes the day's counters when the stored interval date isn't today.
    private func resetIfNewDay(_ defaults: UserDefaults) {
        let today = Self.todayDateString()
        guard defaults.string(forKey: intervalDateKey) != today else { return }
        logger.info("New day \(today): resetting screen time counters")
        defaults.set(0.0, forKey: screenTimeSecondsKey)
        defaults.set(0, forKey: maxThresholdMinutesKey)
        defaults.set(today, forKey: intervalDateKey)
        defaults.set(Date().timeIntervalSince1970, forKey: screenTimeLastUpdatedKey)
    }

    static func parseThresholdMinutes(from event: DeviceActivityEvent.Name) -> Int? {
        let raw = event.rawValue
        guard raw.hasPrefix("st_"), let minutes = Int(raw.dropFirst(3)) else {
            return nil
        }
        return minutes
    }

    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
