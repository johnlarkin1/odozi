import CoreLocation
@testable import Odyssey
import XCTest

final class LocationCaptureServiceTimeoutTests: XCTestCase {
    // The GPS fix timeout in SingleLocationRequest is private and not unit-testable
    // without dependency-injecting CLLocationManager. It is verified on-device by
    // toggling Airplane Mode after launching the BG snapshot. See plan file.

    func testGeocodeTimeoutIsBoundedForBackgroundTaskBudget() async {
        // Reverse geocode must stay well under the BGAppRefreshTask ~30s budget so
        // partial snapshot data (Screen Time, HealthKit) still flows to applySnapshotData
        // when location is unavailable. Bumping this much higher reintroduces the
        // original hang.
        let configured = LocationCaptureService.geocodeTimeout
        let configuredSeconds = Double(configured.components.seconds)
        XCTAssertGreaterThan(configuredSeconds, 0)
        XCTAssertLessThanOrEqual(configuredSeconds, 10)
    }

    func testReverseGeocodeReturnsWithinBudget() async {
        // Smoke test: the geocoder must either resolve or hit the timeout — never hang.
        // Use coordinates in the middle of the Pacific Ocean (no nearby placemark).
        let location = CLLocation(latitude: 0, longitude: 0)
        let configuredSeconds = Double(LocationCaptureService.geocodeTimeout.components.seconds)

        let start = Date()
        _ = await LocationCaptureService.reverseGeocode(location)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, configuredSeconds + 5.0)
    }
}
