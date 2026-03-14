import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SharedDefaults")

enum SharedDefaults {
    static let suiteName = "group.com.johnlarkin.Odyssey"

    static var suite: UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            logger.warning("App Group UserDefaults unavailable, falling back to .standard")
            return .standard
        }
        return defaults
    }

    // Screen Time keys
    static let screenTimeSecondsKey = "screenTimeSeconds"
    static let pickupsKey = "pickups"
    static let screenTimeLastUpdatedKey = "screenTimeLastUpdated"

    static func setScreenTime(seconds: Double, pickups: Int) {
        suite.set(seconds, forKey: screenTimeSecondsKey)
        suite.set(pickups, forKey: pickupsKey)
        suite.set(Date().timeIntervalSince1970, forKey: screenTimeLastUpdatedKey)
    }

    static func getScreenTime() -> (seconds: Double, pickups: Int)? {
        let lastUpdated = suite.double(forKey: screenTimeLastUpdatedKey)
        guard lastUpdated > 0 else { return nil }

        // Only return data updated today
        let updatedDate = Date(timeIntervalSince1970: lastUpdated)
        guard Calendar.current.isDateInToday(updatedDate) else { return nil }

        let seconds = suite.double(forKey: screenTimeSecondsKey)
        let pickups = suite.integer(forKey: pickupsKey)
        return (seconds, pickups)
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
