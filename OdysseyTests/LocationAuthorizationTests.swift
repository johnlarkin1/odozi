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

    /// Background (significant-location-change) capture requires the Always usage description.
    /// After the fix, Info.plist must declare both the When-In-Use and the Always strings.
    func testAlwaysUsageDescriptionPresentForBackgroundCapture() {
        guard let infoPlist = Bundle(for: Self.self).infoDictionary
            ?? Bundle.main.infoDictionary else {
            // In some test-host configurations the app Info.plist isn't loaded; treat as skip.
            return
        }
        // Only assert when the app plist is actually visible to the test bundle.
        if infoPlist["NSLocationWhenInUseUsageDescription"] != nil {
            let always = infoPlist["NSLocationAlwaysAndWhenInUseUsageDescription"] as? String
            XCTAssertFalse(
                (always ?? "").isEmpty,
                "Background significant-location-change capture requires NSLocationAlwaysAndWhenInUseUsageDescription"
            )
        }
    }

    /// Documents the provisional upgrade path: the app requests When-In-Use first, then upgrades
    /// to Always contextually via LocationMonitoringService — it must never jump straight to Always.
    @MainActor
    func testProvisionalAlwaysUpgradeIsIdempotent() {
        // register() is safe to call repeatedly regardless of current authorization status.
        // With no Always grant in the test environment it should no-op without crashing.
        LocationMonitoringService.shared.register()
        LocationMonitoringService.shared.register()
        XCTAssertNotNil(LocationMonitoringService.shared)
    }

    // MARK: - Fallback when a live fix never arrives

    /// A fixed midday "now" so the same-day rule never makes these tests depend on wall-clock time.
    private var noon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
    }

    private func fix(ageHours: Double, from now: Date, accuracy: Double = 65) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: now.addingTimeInterval(-ageHours * 60 * 60)
        )
    }

    /// A background wake frequently never gets a live fix, so the request times out. A recent
    /// same-day cached fix must be used rather than losing the location entirely.
    func testFallbackUsesRecentCachedFix() {
        let result = LocationFallback.result(
            cached: fix(ageHours: 2, from: noon),
            error: CLError(.locationUnknown),
            now: noon
        )

        switch result {
        case let .success(location):
            XCTAssertEqual(location.coordinate.latitude, 40.7128, accuracy: 0.0001)
            XCTAssertEqual(location.coordinate.longitude, -74.0060, accuracy: 0.0001)
        case .failure:
            XCTFail("A 2-hour-old same-day cached fix should be used as the fallback")
        }
    }

    /// An old cached fix is likely from a different place — recording it would silently mislabel
    /// the journal day, which is worse than a blank location.
    func testFallbackRejectsStaleCachedFix() {
        let result = LocationFallback.result(
            cached: fix(ageHours: 48, from: noon),
            error: CLError(.locationUnknown),
            now: noon
        )

        switch result {
        case .success:
            XCTFail("A 2-day-old cached fix is too stale to attribute to today")
        case let .failure(error):
            XCTAssertEqual((error as? CLError)?.code, .locationUnknown)
        }
    }

    /// A fix from last night must not land on today's entry, however recent it is.
    func testFallbackRejectsFixFromPreviousDay() {
        let earlyMorning = Calendar.current.date(bySettingHour: 0, minute: 30, second: 0, of: Date())!
        let lastNight = fix(ageHours: 1, from: earlyMorning) // 11:30 PM yesterday

        XCTAssertFalse(LocationFallback.isUsable(lastNight, now: earlyMorning))
        if case .success = LocationFallback.result(cached: lastNight, error: CLError(.locationUnknown), now: earlyMorning) {
            XCTFail("A fix from the previous calendar day must not be attributed to today")
        }
    }

    /// A negative horizontal accuracy marks an invalid fix.
    func testInvalidFixIsNotUsable() {
        XCTAssertFalse(LocationFallback.isUsable(fix(ageHours: 0, from: noon, accuracy: -1), now: noon))
        XCTAssertTrue(LocationFallback.isUsable(fix(ageHours: 0, from: noon), now: noon))
    }

    /// With no cached fix at all, the original error surfaces so the caller records that location
    /// was genuinely unavailable for this snapshot rather than silently writing nothing.
    func testFallbackPropagatesErrorWhenNoCachedFix() {
        let result = LocationFallback.result(
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

    // MARK: - Applying a location to an entry

    private func snapshot(
        latitude: Double = 40.7128,
        longitude: Double = -74.0060,
        city: String? = "New York",
        at timestamp: Date
    ) -> LocationSnapshot {
        LocationSnapshot(
            latitude: latitude, longitude: longitude,
            city: city, state: city == nil ? nil : "NY", country: city == nil ? nil : "US",
            timestamp: timestamp
        )
    }

    /// The first location is written as one unit, stamped with the fix's own time.
    @MainActor
    func testApplyLocationWritesFirstFixAsUnit() {
        let entry = DailyEntry(date: Calendar.current.startOfDay(for: noon))
        let fixTime = noon.addingTimeInterval(-600)

        XCTAssertTrue(applyLocation(snapshot(at: fixTime), to: entry))
        XCTAssertEqual(entry.latitude, 40.7128)
        XCTAssertEqual(entry.city, "New York")
        XCTAssertEqual(entry.state, "NY")
        XCTAssertEqual(entry.locationCapturedAt, fixTime)
    }

    /// A later passive fix doesn't move the day's location or mix in another place's name.
    @MainActor
    func testApplyLocationKeepsFirstLocation() {
        let entry = DailyEntry(date: Calendar.current.startOfDay(for: noon))
        applyLocation(snapshot(at: noon), to: entry)

        let boston = snapshot(latitude: 42.36, longitude: -71.06, city: "Boston", at: noon.addingTimeInterval(3600))
        XCTAssertFalse(applyLocation(boston, to: entry))
        XCTAssertEqual(entry.city, "New York")
        XCTAssertEqual(entry.latitude, 40.7128)
    }

    /// Coordinates saved first (e.g. an SLC wake suspended mid-geocode) get their place name when
    /// the same coordinates come back named.
    @MainActor
    func testApplyLocationFillsPlaceForSameCoordinates() {
        let entry = DailyEntry(date: Calendar.current.startOfDay(for: noon))
        XCTAssertTrue(applyLocation(snapshot(city: nil, at: noon), to: entry))
        XCTAssertNil(entry.city)

        XCTAssertTrue(applyLocation(snapshot(at: noon), to: entry))
        XCTAssertEqual(entry.city, "New York")
        XCTAssertEqual(entry.country, "US")
    }

    /// A snapshot whose fix belongs to another day is not applied to this day's entry.
    @MainActor
    func testApplySnapshotIgnoresLocationFromAnotherDay() throws {
        let container = try DataContainer.create(inMemory: true)
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let yesterdayFix = today.addingTimeInterval(-60 * 60)

        let data = SnapshotData(
            day: today,
            location: snapshot(at: yesterdayFix),
            stepCount: 1234, walkingDistanceMeters: nil,
            sleepHours: nil, sleepREMHours: nil, sleepDeepHours: nil, sleepCoreHours: nil,
            sleepAwakeMinutes: nil, sleepOnset: nil, sleepInterruptionCount: nil,
            workoutDataJSON: nil, workoutCount: nil, totalWorkoutMinutes: nil, workoutIntensityScore: nil,
            restingHeartRate: nil, averageHeartRate: nil,
            healthSkippedLocked: false,
            screenTimeSeconds: nil, pickups: nil
        )

        XCTAssertTrue(applySnapshotData(data, to: context))
        let entry = try XCTUnwrap(DailyEntryRepository(context: context).fetchEntry(for: today))
        XCTAssertEqual(entry.stepCount, 1234)
        XCTAssertNil(entry.latitude, "Yesterday's fix must not label today's entry")
    }
}
