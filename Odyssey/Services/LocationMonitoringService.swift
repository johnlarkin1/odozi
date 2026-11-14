import CoreLocation
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "LocationMonitoring")

/// Owns the long-lived `CLLocationManager` for **passive** background location capture via
/// significant-location-change (SLC) monitoring.
///
/// SLC is what lets iOS wake — or relaunch, after the app was terminated — Odyssey on meaningful
/// movement (~500 m) and fill in today's location without the user opening the app. It requires:
/// - **Always** authorization;
/// - a manager with its delegate set, and monitoring restarted, **during
///   `application(_:didFinishLaunchingWithOptions:)` on every launch** — on a background relaunch
///   iOS delivers the queued fix to whichever manager exists then, and the SwiftUI scene never
///   becomes active, so a manager created lazily from a foreground path never receives it.
///   `AppDelegate` calls `resumeMonitoringIfAuthorized()` for exactly this reason.
///
/// It does *not* need `allowsBackgroundLocationUpdates` or the `location` background mode; those
/// are for continuous standard updates.
@MainActor
final class LocationMonitoringService: NSObject {
    static let shared = LocationMonitoringService()

    private let manager = CLLocationManager()
    private var isMonitoring = false

    override private init() {
        super.init()
        manager.delegate = self
    }

    /// The app's current location authorization, read from the retained manager.
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    // MARK: - Registration

    /// Launch-time entry point (called from `didFinishLaunching`, including background relaunches).
    /// Never prompts: it only (re)arms monitoring when Always is already granted.
    func resumeMonitoringIfAuthorized() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        startMonitoring()
    }

    /// Foreground entry point. Arms monitoring when Always is granted, and when only When-In-Use
    /// is granted asks iOS for the Always upgrade (shown at most once — later calls are no-ops).
    func register() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startMonitoring()
        case .authorizedWhenInUse:
            logger.info("When-In-Use granted; requesting Always upgrade for background capture")
            manager.requestAlwaysAuthorization()
        default:
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            logger.warning("Significant-location-change monitoring unavailable on this device")
            return
        }
        // Calling start while the system already considers us monitoring (e.g. after a relaunch)
        // is fine and is exactly what Apple requires to resume delivery in a new process.
        manager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
        logger.info("Started significant-location-change monitoring")
    }

    private func stopMonitoring() {
        guard isMonitoring else { return }
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
        logger.info("Stopped significant-location-change monitoring")
    }

    private func authorizationDidChange() {
        // Re-evaluate without prompting: start when Always arrives (e.g. the upgrade was just
        // granted), stop when access is revoked in Settings.
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startMonitoring()
        case .authorizedWhenInUse:
            break
        default:
            stopMonitoring()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMonitoringService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        Task { @MainActor in
            self.authorizationDidChange()
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Delegate callbacks arrive on the thread the manager was created on — the main thread,
        // since this class is main-actor isolated. Handle synchronously (no Task hop) so the
        // background-task assertion is taken before this callback returns: after an SLC wake iOS
        // gives the app only a few seconds before suspending it again.
        MainActor.assumeIsolated {
            // Use the fix iOS just delivered. Asking for a *new* one from the background is slow,
            // often never answered, and wastes the wake's short time budget.
            guard let fix = locations.last(where: { LocationFallback.isUsable($0) }) else {
                logger.info("SLC delivery had no usable fix (\(locations.count) locations)")
                return
            }
            logger.info("SLC delivered a fix (accuracy \(fix.horizontalAccuracy, format: .fixed(precision: 0))m)")
            BackgroundSnapshotService.handleSignificantLocationChange(fix)
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("Significant-location-change monitoring failed: \(error.localizedDescription)")
    }
}
