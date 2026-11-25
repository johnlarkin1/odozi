#if os(iOS)
    import DeviceActivity
    import FamilyControls
    import Foundation
    import os

    private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "ScreenTimeMonitoring")

    enum ScreenTimeMonitoringManager {
        static let activityName = DeviceActivityName("OdysseyDaily")

        /// App Group key holding the encoded `FamilyActivitySelection` the user picked.
        static let selectionKey = "selectedAppsToMonitor"
        /// App Group key holding the encoded selection that monitoring was last started with.
        static let registeredSelectionKey = "screenTimeRegisteredSelection"

        static let thresholdMinutes: [Int] = [
            1, 5, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180,
            210, 240, 300, 360, 420, 480, 540, 600, 720, 840, 960
        ]

        /// Why Screen Time can or can't be captured right now.
        enum SetupState: Equatable {
            /// Family Controls permission hasn't been granted.
            case notAuthorized
            /// Permission granted, but no apps or categories picked. Threshold events need
            /// at least one token, so nothing is monitored until the user picks some.
            case noSelection
            case ready
        }

        static var setupState: SetupState {
            #if targetEnvironment(simulator)
                return .notAuthorized
            #else
                guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                    return .notAuthorized
                }
                let selection = loadSelection()
                guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                    return .noSelection
                }
                return .ready
            #endif
        }

        /// Registers device activity monitoring with threshold events.
        ///
        /// Idempotent: when monitoring is already running with the same selection, this does
        /// nothing. Restarting mid-day makes the system re-deliver `intervalDidStart` and restart
        /// threshold counting, which used to wipe the day's captured screen time on every
        /// foreground. Pass `force: true` after the selection changes.
        static func register(force: Bool = false) {
            #if targetEnvironment(simulator)
                logger.info("Skipping monitoring registration on simulator")
                return
            #else
                guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                    logger.info("FamilyControls not authorized, skipping registration")
                    return
                }

                let defaults = UserDefaults(suiteName: SharedDefaults.suiteName)
                let selectionData = defaults?.data(forKey: selectionKey)
                let selection = loadSelection()
                guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                    logger.info("No apps/categories selected, skipping registration")
                    return
                }

                let center = DeviceActivityCenter()
                let alreadyMonitoring = center.activities.contains(activityName)
                let sameSelection = selectionData != nil
                    && defaults?.data(forKey: registeredSelectionKey) == selectionData
                if !force && alreadyMonitoring && sameSelection {
                    logger.info("Monitoring already active with current selection, leaving it running")
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

                // Must stop then start (required since iOS 18 Beta 2)
                center.stopMonitoring([activityName])

                do {
                    try center.startMonitoring(activityName, during: schedule, events: events)
                    defaults?.set(selectionData, forKey: registeredSelectionKey)
                    logger.info("Registered monitoring with \(events.count) threshold events")
                } catch {
                    defaults?.removeObject(forKey: registeredSelectionKey)
                    logger.error("Failed to start monitoring: \(error)")
                }
            #endif
        }

        static func loadSelection() -> FamilyActivitySelection {
            let defaults = UserDefaults(suiteName: SharedDefaults.suiteName)
            guard let data = defaults?.data(forKey: selectionKey),
                  let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else {
                return FamilyActivitySelection()
            }
            return selection
        }
    }
#endif
