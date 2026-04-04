@testable import Odyssey
import XCTest

final class SharedDefaultsWidgetTests: XCTestCase {
    override func setUp() {
        // Clear widget keys before each test
        let suite = SharedDefaults.suite
        suite.removeObject(forKey: SharedDefaults.widgetMoodValueKey)
        suite.removeObject(forKey: SharedDefaults.widgetMoodTimestampKey)
    }

    override func tearDown() {
        let suite = SharedDefaults.suite
        suite.removeObject(forKey: SharedDefaults.widgetMoodValueKey)
        suite.removeObject(forKey: SharedDefaults.widgetMoodTimestampKey)
    }

    // MARK: - setWidgetMood / getWidgetMood

    func testGetWidgetMoodReturnsNilWhenNeverSet() {
        let result = SharedDefaults.getWidgetMood()
        XCTAssertNil(result)
    }

    func testSetAndGetWidgetMoodRoundTrips() {
        SharedDefaults.setWidgetMood(value: 7)

        let result = SharedDefaults.getWidgetMood()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.value, 7)
    }

    func testGetWidgetMoodDateIsToday() {
        SharedDefaults.setWidgetMood(value: 5)

        let result = SharedDefaults.getWidgetMood()
        XCTAssertNotNil(result)
        XCTAssertTrue(Calendar.current.isDateInToday(result!.date))
    }

    func testGetWidgetMoodReturnsNilForStaleTimestamp() {
        // Write a timestamp from yesterday
        let suite = SharedDefaults.suite
        suite.set(8, forKey: SharedDefaults.widgetMoodValueKey)
        let yesterday = Date().addingTimeInterval(-86400 * 2)
        suite.set(yesterday.timeIntervalSince1970, forKey: SharedDefaults.widgetMoodTimestampKey)

        let result = SharedDefaults.getWidgetMood()
        XCTAssertNil(result, "Should return nil for non-today timestamps")
    }

    func testSetWidgetMoodOverwritesPreviousValue() {
        SharedDefaults.setWidgetMood(value: 3)
        SharedDefaults.setWidgetMood(value: 9)

        let result = SharedDefaults.getWidgetMood()
        XCTAssertEqual(result?.value, 9)
    }

    func testWidgetMoodValueRange() {
        // Test edge values
        for value in [1, 5, 10] {
            SharedDefaults.setWidgetMood(value: value)
            let result = SharedDefaults.getWidgetMood()
            XCTAssertEqual(result?.value, value)
        }
    }

    // MARK: - Screen Time

    override static var defaultTestSuite: XCTestSuite {
        // Include screen time cleanup in setUp/tearDown
        super.defaultTestSuite
    }

    private func clearScreenTimeKeys() {
        let suite = SharedDefaults.suite
        suite.removeObject(forKey: SharedDefaults.screenTimeSecondsKey)
        suite.removeObject(forKey: SharedDefaults.pickupsKey)
        suite.removeObject(forKey: SharedDefaults.screenTimeLastUpdatedKey)
    }

    func testGetScreenTimeReturnsNilWhenNeverWritten() {
        clearScreenTimeKeys()
        let result = SharedDefaults.getScreenTime()
        XCTAssertNil(result)
    }

    func testGetScreenTimeReturnsNilWhenStale() {
        let suite = SharedDefaults.suite
        suite.set(3600.0, forKey: SharedDefaults.screenTimeSecondsKey)
        suite.set(10, forKey: SharedDefaults.pickupsKey)
        let yesterday = Date().addingTimeInterval(-86400 * 2)
        suite.set(yesterday.timeIntervalSince1970, forKey: SharedDefaults.screenTimeLastUpdatedKey)

        let result = SharedDefaults.getScreenTime()
        XCTAssertNil(result, "Should return nil for non-today timestamps")

        clearScreenTimeKeys()
    }

    func testSetAndGetScreenTimeRoundTrips() {
        clearScreenTimeKeys()
        SharedDefaults.setScreenTime(seconds: 7200.0, pickups: 42)

        let result = SharedDefaults.getScreenTime()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.seconds, 7200.0)
        XCTAssertEqual(result?.pickups, 42)

        clearScreenTimeKeys()
    }

    func testGetScreenTimeReturnsTodaysData() {
        clearScreenTimeKeys()
        SharedDefaults.setScreenTime(seconds: 5400.0, pickups: 25)

        let result = SharedDefaults.getScreenTime()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.seconds, 5400.0)
        XCTAssertEqual(result?.pickups, 25)

        clearScreenTimeKeys()
    }

    func testGetScreenTimeDebugInfoFormat() {
        clearScreenTimeKeys()
        let info = SharedDefaults.getScreenTimeDebugInfo()
        XCTAssertTrue(info.contains("screenTime="))
        XCTAssertTrue(info.contains("isToday="))

        clearScreenTimeKeys()
    }
}
