import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SharedDefaults")

enum SharedDefaults {
    static let suiteName = "group.com.johnlarkin.Odyssey"

    static var suite: UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("App Group '\(suiteName)' unavailable — check entitlements")
            logger.fault("App Group UserDefaults unavailable, falling back to .standard")
            return .standard
        }
        return defaults
    }

    // Screen Time keys (written by DeviceActivityMonitorExtension)
    static let screenTimeSecondsKey = "screenTimeSeconds"
    static let pickupsKey = "pickups"
    static let screenTimeLastUpdatedKey = "screenTimeLastUpdated"
    static let maxThresholdMinutesKey = "screenTimeMaxThresholdMinutes"
    static let intervalDateKey = "screenTimeIntervalDate"

    static func setScreenTime(seconds: Double, pickups: Int) {
        suite.set(seconds, forKey: screenTimeSecondsKey)
        suite.set(pickups, forKey: pickupsKey)
        suite.set(Date().timeIntervalSince1970, forKey: screenTimeLastUpdatedKey)
    }

    static func getScreenTime() -> (seconds: Double, pickups: Int)? {
        let lastUpdated = suite.double(forKey: screenTimeLastUpdatedKey)
        guard lastUpdated > 0 else {
            logger.debug("Screen time: no lastUpdated timestamp found")
            return nil
        }

        // Only return data updated today
        let updatedDate = Date(timeIntervalSince1970: lastUpdated)
        guard Calendar.current.isDateInToday(updatedDate) else {
            logger.debug("Screen time: stale data from \(updatedDate)")
            return nil
        }

        let seconds = suite.double(forKey: screenTimeSecondsKey)
        let pickups = suite.integer(forKey: pickupsKey)
        logger.debug("Screen time: \(seconds)s, \(pickups) pickups")
        return (seconds, pickups)
    }

    #if DEBUG
        /// Returns the path this process resolves `group.com.johnlarkin.Odyssey` to.
        /// Returns nil if this process isn't entitled for the App Group.
        static func appGroupContainerPath() -> String? {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
                .path
        }
    #endif

    static func getScreenTimeDebugInfo() -> String {
        let lastUpdated = suite.double(forKey: screenTimeLastUpdatedKey)
        let seconds = suite.double(forKey: screenTimeSecondsKey)
        let pickups = suite.integer(forKey: pickupsKey)
        let updatedDate = lastUpdated > 0 ? "\(Date(timeIntervalSince1970: lastUpdated))" : "never"
        let isToday = lastUpdated > 0 && Calendar.current.isDateInToday(Date(timeIntervalSince1970: lastUpdated))
        return "screenTime=\(seconds)s pickups=\(pickups) updated=\(updatedDate) isToday=\(isToday)"
    }

    // MARK: - Passive capture outcomes (visibility for location + HealthKit)

    static let lastCaptureAtKey = "passiveCaptureLastRunAt"
    static let lastLocationOutcomeKey = "passiveCaptureLocationOutcome"
    static let lastHealthOutcomeKey = "passiveCaptureHealthOutcome"

    /// Record why the most recent location capture did or didn't produce a fix
    /// (e.g. "ok Brooklyn", "denied", "notDetermined", "unavailable").
    static func setLocationCaptureOutcome(_ outcome: String) {
        suite.set(outcome, forKey: lastLocationOutcomeKey)
    }

    /// Record the most recent HealthKit capture outcome (e.g. "ok", "empty", "skipped-locked").
    static func setHealthCaptureOutcome(_ outcome: String) {
        suite.set(outcome, forKey: lastHealthOutcomeKey)
    }

    /// Stamp the time a snapshot capture run last completed (any trigger: foreground, BGTask,
    /// significant-location-change wake, or HealthKit observer).
    static func markCaptureRun() {
        suite.set(Date().timeIntervalSince1970, forKey: lastCaptureAtKey)
    }

    static func getCaptureDebugInfo() -> String {
        let ts = suite.double(forKey: lastCaptureAtKey)
        let when = ts > 0 ? "\(Date(timeIntervalSince1970: ts))" : "never"
        let isToday = ts > 0 && Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts))
        let location = suite.string(forKey: lastLocationOutcomeKey) ?? "—"
        let health = suite.string(forKey: lastHealthOutcomeKey) ?? "—"
        return "lastCapture=\(when) isToday=\(isToday) location=\(location) health=\(health)"
    }

    // Widget <-> App communication
    static let widgetMoodValueKey = "widgetMoodValue"
    static let widgetMoodTimestampKey = "widgetMoodTimestamp"

    static func setWidgetMood(value: Int) {
        suite.set(value, forKey: widgetMoodValueKey)
        suite.set(Date().timeIntervalSince1970, forKey: widgetMoodTimestampKey)
    }

    static func getWidgetMood() -> (value: Int, date: Date)? {
        let timestamp = suite.double(forKey: widgetMoodTimestampKey)
        guard timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        guard Calendar.current.isDateInToday(date) else { return nil }
        return (suite.integer(forKey: widgetMoodValueKey), date)
    }
}
