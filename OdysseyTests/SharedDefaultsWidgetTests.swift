import XCTest
@testable import Odyssey

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
}
