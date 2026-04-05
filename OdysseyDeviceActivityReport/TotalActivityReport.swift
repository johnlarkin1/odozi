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
        logger.info("makeConfiguration called")
        #if DEBUG
            NSLog("[Odyssey DAR] makeConfiguration called pid=%d", getpid())

            // Breadcrumb: makeConfiguration entered (before any data iteration).
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.johnlarkin.Odyssey"
            ) {
                let url = container.appendingPathComponent("dar_makeconfig_entered.json")
                let payload: [String: Any] = [
                    "ts": Date().timeIntervalSince1970,
                    "pid": getpid()
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload) {
                    try? data.write(to: url, options: .atomic)
                    NSLog("[Odyssey DAR] wrote dar_makeconfig_entered.json")
                }
            }
        #endif

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

        // Write to shared defaults so main app can read
        // Keys must match SharedDefaults.screenTimeSecondsKey / .pickupsKey / .screenTimeLastUpdatedKey
        let suiteName = "group.com.johnlarkin.Odyssey"
        let stamp = Date().timeIntervalSince1970

        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.set(totalDuration, forKey: "screenTimeSeconds")
            defaults.set(totalPickups, forKey: "pickups")
            defaults.set(stamp, forKey: "screenTimeLastUpdated")
            defaults.synchronize()
            #if DEBUG
                // Canary: write-then-read-back in-process to detect silent sandbox drops.
                let readback = defaults.double(forKey: "screenTimeLastUpdated")
                let matches = abs(readback - stamp) < 0.01
                logger.info("DAR UD write stamp=\(stamp) readback=\(readback) match=\(matches)")
            #endif
        } else {
            logger.error("DAR: UserDefaults(suiteName: \(suiteName)) returned nil — App Group not entitled")
        }

        #if DEBUG
            // File-based fallback in the App Group container — survives even if
            // cross-process UserDefaults propagation is blocked by the sandbox.
            var fileWriteResult = "skipped"
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: suiteName
            )
            let pathSuffix = container?.path.suffix(12) ?? "nil"
            if let container {
                let url = container.appendingPathComponent("screentime.json")
                let payload: [String: Any] = [
                    "seconds": totalDuration,
                    "pickups": totalPickups,
                    "ts": stamp
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload) {
                    do {
                        try data.write(to: url, options: .atomic)
                        if let readData = try? Data(contentsOf: url) {
                            fileWriteResult = "OK(\(readData.count)B)"
                        } else {
                            fileWriteResult = "wrote-no-readback"
                        }
                    } catch {
                        fileWriteResult = "THREW"
                    }
                }
            }

            // Encode diagnostics INTO the return string — the one channel Apple
            // guarantees reaches the main app from the DAR extension sandbox.
            let baseStr = formatter.string(from: totalDuration) ?? "0s"
            let shortTs = Int(stamp) % 100000
            return "v4 pid=\(getpid()) t=\(shortTs) f=\(fileWriteResult) |\(pathSuffix)| \(baseStr)"
        #else
            return formatter.string(from: totalDuration) ?? "No activity data"
        #endif
    }
}
