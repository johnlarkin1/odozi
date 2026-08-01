import CoreLocation
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "LocationMonitoring")

/// Owns a long-lived `CLLocationManager` for **passive** background location capture via
/// significant-location-change (SLC) monitoring.
///
/// This is distinct from `LocationCaptureService`, which does a one-shot `requestLocation()`
/// while the app is foreground. SLC is what lets iOS wake the *suspended* app on meaningful
/// movement and fill in today's entry without the user opening the app — but it only works
/// with **Always** authorization plus the `location` background mode (Info.plist) and, for
/// `allowsBackgroundLocationUpdates`, a retained manager + delegate (why this is a singleton).
///
/// `register()` mirrors `ScreenTimeMonitoringManager.register()`: safe to call repeatedly,
/// no-ops when not eligible, and is re-armed defensively on every foreground.
@MainActor
final class LocationMonitoringService: NSObject {
    static let shared = LocationMonitoringService()

    private let manager = CLLocationManager()
    private var isMonitoring = false

    override private init() {
        super.init()
        manager.delegate = self
    }

    /// The app's current location authorization, read from the retained manager. Callers should
    /// use this instead of allocating a throwaway `CLLocationManager` just to read a status —
    /// the modern `authorizationStatus` is an instance property, so every such read would
    /// otherwise construct and discard a manager.
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    // MARK: - Registration

    /// Starts significant-location-change monitoring when the app holds Always authorization.
    /// Safe to call repeatedly — stops and restarts to stay idempotent. No-op otherwise.
    func register() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startMonitoring()
        case .authorizedWhenInUse:
            // Have foreground access — ask iOS to upgrade to Always so background capture works.
            // iOS shows the "Keep Allowing / Change to Always" prompt at most once; harmless to re-request.
            logger.info("When-In-Use granted; requesting Always upgrade for background capture")
            manager.requestAlwaysAuthorization()
        default:
            logger.info("Location not authorized for background monitoring (status: \(self.manager.authorizationStatus.rawValue))")
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            logger.warning("Significant-location-change monitoring unavailable on this device")
            return
        }
        // These require Always authorization + the `location` background mode; only reached
        // from the .authorizedAlways branch above.
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true

        // Restart to stay idempotent (mirrors ScreenTimeMonitoringManager's stop-then-start).
        manager.stopMonitoringSignificantLocationChanges()
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

    // MARK: - Snapshot on wake

    /// An SLC delivery can wake a suspended app. Run the same snapshot path the BGTasks use so
    /// location/health get filled in. Deliveries arrive in bursts while travelling, so this goes
    /// through the debounced shared entry point rather than capturing on every one.
    private func captureSnapshotOnWake() {
        Task {
            await BackgroundSnapshotService.captureAndApply(trigger: "significant-location-change wake")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMonitoringService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            // Re-evaluate on any authorization change (e.g. the Always upgrade being granted,
            // or the user revoking access in Settings).
            self.register()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !locations.isEmpty else { return }
        Task { @MainActor in
            self.captureSnapshotOnWake()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Significant-location-change monitoring failed: \(error.localizedDescription)")
    }
}
