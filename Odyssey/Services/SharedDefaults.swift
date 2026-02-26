import Foundation

enum SharedDefaults {
    static let suiteName = "group.com.johnlarkin.Odyssey"

    static var suite: UserDefaults {
        UserDefaults(suiteName: suiteName)!
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
}
