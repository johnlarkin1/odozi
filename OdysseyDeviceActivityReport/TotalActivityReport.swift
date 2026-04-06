import DeviceActivity
import os
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "TotalActivityReport")

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

        logger.info("Screen time: \(totalDuration)s, pickups: \(totalPickups)")

        return formatter.string(from: totalDuration) ?? "No activity data"
    }
}
