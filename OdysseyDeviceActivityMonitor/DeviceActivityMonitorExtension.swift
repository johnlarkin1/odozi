import DeviceActivity
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Write timestamp to shared defaults so main app knows data is available
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastIntervalEnd")

        // Post Darwin notification to wake main app if in foreground
        let name = "com.johnlarkin.Odyssey.intervalEnded" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name),
            nil,
            nil,
            true
        )
    }
}
