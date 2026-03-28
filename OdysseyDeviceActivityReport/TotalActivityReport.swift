import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        var totalDuration: TimeInterval = 0
        var totalPickups = 0

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration
                for await category in segment.categories {
                    for await application in category.applications {
                        totalPickups += application.numberOfPickups
                    }
                }
            }
        }

        // Write to shared defaults so main app can read
        // Keys must match SharedDefaults.screenTimeSecondsKey / .pickupsKey / .screenTimeLastUpdatedKey
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        defaults?.set(totalDuration, forKey: "screenTimeSeconds")
        defaults?.set(totalPickups, forKey: "pickups")
        defaults?.set(Date().timeIntervalSince1970, forKey: "screenTimeLastUpdated")
        defaults?.synchronize()

        return formatter.string(from: totalDuration) ?? "No activity data"
    }
}
