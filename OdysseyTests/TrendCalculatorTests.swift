@testable import Odyssey
import XCTest

final class TrendCalculatorTests: XCTestCase {
    func testFlatForEmptyEntries() {
        let trend = TrendCalculator.trend(for: .mood, entries: [])
        XCTAssertEqual(trend.direction, .flat)
        XCTAssertEqual(trend.percentage, 0)
    }

    func testFlatForSingleEntry() {
        let entries = [makeEntry(daysAgo: 0, feeling: 7)]
        let trend = TrendCalculator.trend(for: .mood, entries: entries)
        XCTAssertEqual(trend.direction, .flat)
    }

    func testUpWhenCurrentHalfHigher() {
        // Prior half: feeling 3,4  Current half: feeling 8,9
        let entries = [
            makeEntry(daysAgo: 4, feeling: 3),
            makeEntry(daysAgo: 3, feeling: 4),
            makeEntry(daysAgo: 1, feeling: 8),
            makeEntry(daysAgo: 0, feeling: 9)
        ]
        let trend = TrendCalculator.trend(for: .mood, entries: entries)
        XCTAssertEqual(trend.direction, .up)
        XCTAssertGreaterThan(trend.percentage, 0)
    }

    func testDownWhenCurrentHalfLower() {
        // Prior half: feeling 8,9  Current half: feeling 3,4
        let entries = [
            makeEntry(daysAgo: 4, feeling: 8),
            makeEntry(daysAgo: 3, feeling: 9),
            makeEntry(daysAgo: 1, feeling: 3),
            makeEntry(daysAgo: 0, feeling: 4)
        ]
        let trend = TrendCalculator.trend(for: .mood, entries: entries)
        XCTAssertEqual(trend.direction, .down)
        XCTAssertGreaterThan(trend.percentage, 0)
    }

    func testFlatWhenChangeLessThanOnePercent() {
        // Prior avg = 100, current avg = 100.5 → 0.5% change → flat
        let entries = [
            makeEntry(daysAgo: 2, stepCount: 100),
            makeEntry(daysAgo: 1, stepCount: 100),
            makeEntry(daysAgo: 0, stepCount: 101)
        ]
        let trend = TrendCalculator.trend(for: .steps, entries: entries)
        XCTAssertEqual(trend.direction, .flat)
    }

    func testPercentageCalculation() {
        // Prior half: avg = 5.0, Current half: avg = 10.0 → 100% increase
        let entries = [
            makeEntry(daysAgo: 2, feeling: 5),
            makeEntry(daysAgo: 0, feeling: 10)
        ]
        let trend = TrendCalculator.trend(for: .mood, entries: entries)
        XCTAssertEqual(trend.direction, .up)
        XCTAssertEqual(trend.percentage, 100.0, accuracy: 0.01)
    }

    func testUpFromZeroPriorAverage() {
        // Prior avg = 0 (nil stepCount → excluded), but we need at least 2 values
        // Use drinks: prior half all 0, current half > 0
        let entries = [
            makeEntry(daysAgo: 2, drinks: 0),
            makeEntry(daysAgo: 0, drinks: 3)
        ]
        let trend = TrendCalculator.trend(for: .drinks, entries: entries)
        XCTAssertEqual(trend.direction, .up)
        XCTAssertEqual(trend.percentage, 100)
    }

    func testFlatWhenBothHalvesZero() {
        let entries = [
            makeEntry(daysAgo: 2, drinks: 0),
            makeEntry(daysAgo: 0, drinks: 0)
        ]
        let trend = TrendCalculator.trend(for: .drinks, entries: entries)
        XCTAssertEqual(trend.direction, .flat)
    }

    func testSkipsEntriesWithNilMetricValues() {
        // Steps: only 1 entry has a value → fewer than 2 → flat
        let entries = [
            makeEntry(daysAgo: 2),
            makeEntry(daysAgo: 1),
            makeEntry(daysAgo: 0, stepCount: 5000)
        ]
        let trend = TrendCalculator.trend(for: .steps, entries: entries)
        XCTAssertEqual(trend.direction, .flat)
    }
}
