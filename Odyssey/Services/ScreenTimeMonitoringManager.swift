#if os(iOS)
    import DeviceActivity
    import FamilyControls
    import Foundation
    import os

    private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "ScreenTimeMonitoring")

    enum ScreenTimeMonitoringManager {
        static let activityName = DeviceActivityName("OdysseyDaily")

        static let thresholdMinutes: [Int] = [
            1, 5, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180,
            210, 240, 300, 360, 420, 480, 540, 600, 720, 840, 960
        ]

        /// Registers (or re-registers) device activity monitoring with threshold events.
        /// Safe to call repeatedly — stops existing monitoring first.
        static func register() {
            #if targetEnvironment(simulator)
                logger.info("Skipping monitoring registration on simulator")
                return
            #else
                guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                    logger.info("FamilyControls not authorized, skipping registration")
                    return
                }

                let selection = loadSelection()
                guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                    logger.info("No apps/categories selected, skipping registration")
                    return
                }

                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: 0, minute: 0),
                    intervalEnd: DateComponents(hour: 23, minute: 59),
                    repeats: true
                )

                var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
                for minutes in thresholdMinutes {
                    let eventName = DeviceActivityEvent.Name("st_\(minutes)")
                    events[eventName] = DeviceActivityEvent(
                        applications: selection.applicationTokens,
                        categories: selection.categoryTokens,
                        threshold: DateComponents(minute: minutes)
                    )
                }

                let center = DeviceActivityCenter()

                // Must stop then start (required since iOS 18 Beta 2)
                center.stopMonitoring([activityName])

                do {
                    try center.startMonitoring(activityName, during: schedule, events: events)
                    logger.info("Registered monitoring with \(events.count) threshold events")
                } catch {
                    logger.error("Failed to start monitoring: \(error)")
                }
            #endif
        }

        private static func loadSelection() -> FamilyActivitySelection {
            let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
            guard let data = defaults?.data(forKey: "selectedAppsToMonitor"),
                  let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else {
                return FamilyActivitySelection()
            }
            return selection
        }
    }
#endif
