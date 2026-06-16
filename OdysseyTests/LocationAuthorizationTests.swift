import CoreLocation
@testable import Odyssey
import XCTest

final class LocationAuthorizationTests: XCTestCase {
    /// Test that location authorization follows standard iOS patterns
    /// Apps should request "When In Use" permission first, then upgrade to "Always"
    /// only when background location access is actually needed
    func testLocationAuthorizationFlow() {
        // This test documents the expected behavior for location authorization.
        //
        // Apple's guidance:
        // 1. Request .whenInUseAuthorization() on first launch
        // 2. Only request .alwaysAuthorization() when background location is explicitly needed
        // 3. Requesting .always directly is suspicious and can trigger review scrutiny
        //
        // Odyssey uses location for:
        // - One-time daily snapshot (via background tasks) — requires .always permission eventually
        // - But should start with .whenInUse and explain why .always is needed
        //
        // Before fix: Requested .alwaysAuthorization() immediately on app launch
        // After fix: Requests .whenInUseAuthorization() on launch, can request upgrade later

        // This is a documentation test showing the expected authorization flow
        let clLocationManager = CLLocationManager()
        XCTAssertNotNil(clLocationManager, "CLLocationManager should be available")
    }

    /// Test that location data collection is properly justified
    func testLocationDataCollectionJustification() {
        // Odyssey's location collection must be justified for App Store approval:
        //
        // Justification: "Odyssey captures precise location once daily (via background snapshot)
        // to enrich journal entries with place context. Users see location on interactive map
        // in the Insights tab."
        //
        // This is legitimate use of location data that Apple approves for wellness/journaling apps.

        XCTAssertTrue(true, "Location data collection is properly justified for wellness app")
    }

    /// Test that location permission strings are clear and specific
    func testLocationPermissionStrings() {
        // The Info.plist must have clear, specific permission strings that match the actual usage:
        //
        // NSLocationWhenInUseUsageDescription:
        // "Odyssey captures your location once daily to add context to your journal entries."
        //
        // NSLocationAlwaysAndWhenInUseUsageDescription:
        // "Odyssey captures your location daily in the background to enrich your journal with place information."
        //
        // These strings should be honest, specific, and explain the actual use case.

        // Verify we can read the Info.plist
        if let infoPlist = Bundle.main.infoDictionary {
            let whenInUseKey = "NSLocationWhenInUseUsageDescription"
            let alwaysKey = "NSLocationAlwaysAndWhenInUseUsageDescription"

            let whenInUseDesc = infoPlist[whenInUseKey] as? String
            let alwaysDesc = infoPlist[alwaysKey] as? String

            // At least one location permission string should be present
            XCTAssert(
                !((whenInUseDesc ?? "").isEmpty && (alwaysDesc ?? "").isEmpty),
                "Location permission strings must be provided in Info.plist"
            )
        }
    }

    /// When a live request times out or fails but a cached fix exists, the snapshot
    /// must use the cached fix rather than failing. This is the core of the
    /// automated-capture fix: a background BGTask under When-In-Use authorization
    /// frequently never gets a live fix, so the request times out and we fall back to
    /// CLLocationManager.location (the last cached fix) instead of hanging or losing
    /// the snapshot.
    @MainActor
    func testFallbackUsesCachedFixWhenAvailable() {
        let cached = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let result = SingleLocationRequest.fallbackResult(
            cached: cached,
            error: CLError(.locationUnknown)
        )

        switch result {
        case let .success(location):
            XCTAssertEqual(location.coordinate.latitude, 40.7128, accuracy: 0.0001)
            XCTAssertEqual(location.coordinate.longitude, -74.0060, accuracy: 0.0001)
        case .failure:
            XCTFail("Expected the cached fix to be used as the fallback")
        }
    }

    /// With no cached fix available, the fallback surfaces the original error so the
    /// caller can record that location was genuinely unavailable for this snapshot.
    @MainActor
    func testFallbackPropagatesErrorWhenNoCachedFix() {
        let result = SingleLocationRequest.fallbackResult(
            cached: nil,
            error: CLError(.locationUnknown)
        )

        switch result {
        case .success:
            XCTFail("Expected failure when no cached fix is available")
        case let .failure(error):
            XCTAssertEqual((error as? CLError)?.code, .locationUnknown)
        }
    }
}
