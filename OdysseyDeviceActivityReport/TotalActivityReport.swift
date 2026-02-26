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

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration
            }
        }

        // Write to shared defaults as side effect
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        defaults?.set(totalDuration, forKey: "screenTimeSeconds")
        defaults?.set(Date().timeIntervalSince1970, forKey: "screenTimeLastUpdated")

        return formatter.string(from: totalDuration) ?? "No activity data"
    }
}
