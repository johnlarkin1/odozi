@testable import Odyssey
import XCTest

final class CorrelationServiceTests: XCTestCase {
    // MARK: - correlate()

    func testReturnsNilForFewerThanSevenPairs() {
        let entries = (0 ..< 6).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNil(result)
    }

    func testExactlySevenPairsSucceeds() {
        let entries = (0 ..< 7).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNotNil(result)
    }

    func testReturnsNilWhenAllValuesIdentical() {
        // Zero variance → denominator is 0
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: 5, stepCount: 3000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNil(result)
    }

    func testPerfectPositiveCorrelation() {
        // feeling = i+1, stepCount = (i+1)*1000 → perfectly linear
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.coefficient, 1.0, accuracy: 0.001)
    }

    func testPerfectNegativeCorrelation() {
        // feeling goes up, stepCount goes down
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: (10 - $0) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.coefficient, -1.0, accuracy: 0.001)
    }

    func testModerateCorrelation() {
        // Noisy but positive relationship
        let feelings = [3, 4, 5, 6, 7, 8, 9, 7, 6, 8]
        let steps = [2000, 3000, 4000, 5000, 6000, 7000, 8000, 5000, 4000, 9000]
        let entries = zip(feelings, steps).enumerated().map { i, pair in
            makeEntry(daysAgo: i, feeling: pair.0, stepCount: pair.1)
        }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNotNil(result)
        // Should be moderately to strongly positive
        XCTAssertGreaterThan(result!.coefficient, 0.4)
        XCTAssertLessThan(result!.coefficient, 1.0)
    }

    func testSkipsEntriesWithNilValues() {
        // 10 entries, but some have nil stepCount → fewer than 7 valid pairs
        var entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1) }
        // Only give 5 of them stepCount
        for i in 0 ..< 5 {
            entries[i] = makeEntry(daysAgo: i, feeling: i + 1, stepCount: (i + 1) * 1000)
        }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)
        XCTAssertNil(result, "Should be nil because only 5 valid pairs exist")
    }

    // MARK: - generateInsight (tested via correlate)

    func testInsightTextStronglyPositive() {
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)!
        XCTAssertTrue(result.insightText.contains("strongly"))
        XCTAssertTrue(result.insightText.contains("positively"))
    }

    func testInsightTextStronglyNegative() {
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: (10 - $0) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)!
        XCTAssertTrue(result.insightText.contains("strongly"))
        XCTAssertTrue(result.insightText.contains("negatively"))
    }

    func testInsightTextContainsMetricNames() {
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)!
        XCTAssertTrue(result.insightText.contains("Mood"))
        XCTAssertTrue(result.insightText.contains("Steps"))
    }

    func testInsightTextContainsCoefficient() {
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, stepCount: ($0 + 1) * 1000) }
        let result = CorrelationService.correlate(.mood, .steps, entries: entries)!
        XCTAssertTrue(result.insightText.contains("r="))
    }

    // MARK: - strongestCorrelation

    func testStrongestCorrelationSkipsTrivialPairs() {
        // Create entries where steps and walkingDistance are perfectly correlated (trivial pair)
        // but mood and steps have moderate correlation
        let entries = (0 ..< 10).map {
            makeEntry(
                daysAgo: $0,
                feeling: $0 + 1,
                stepCount: ($0 + 1) * 1000,
                walkingDistanceMeters: Double(($0 + 1) * 800)
            )
        }
        let result = CorrelationService.strongestCorrelation(entries: entries)
        if let result {
            // Should not be steps+walkingDistance since that's a trivial pair
            let isStepsDistance = (result.metricA == .steps && result.metricB == .walkingDistance) ||
                (result.metricA == .walkingDistance && result.metricB == .steps)
            XCTAssertFalse(isStepsDistance, "Should skip trivial pairs")
        }
    }

    func testStrongestCorrelationReturnsNilForInsufficientData() {
        let entries = (0 ..< 3).map { makeEntry(daysAgo: $0, feeling: $0 + 1) }
        let result = CorrelationService.strongestCorrelation(entries: entries)
        XCTAssertNil(result)
    }
}
