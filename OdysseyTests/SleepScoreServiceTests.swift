@testable import Odyssey
import XCTest

final class SleepScoreServiceTests: XCTestCase {

    // MARK: - Duration Points (50 max)

    func testDurationZeroHours() {
        let entry = DailyEntry(sleepHours: 0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 0)
    }

    func testDurationThreeAndHalfHours() {
        let entry = DailyEntry(sleepHours: 3.5)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 25)
    }

    func testDurationSevenHoursFullPoints() {
        let entry = DailyEntry(sleepHours: 7.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 50)
    }

    func testDurationEightHoursFullPoints() {
        let entry = DailyEntry(sleepHours: 8.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 50)
    }

    func testDurationNineHoursFullPoints() {
        let entry = DailyEntry(sleepHours: 9.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 50)
    }

    func testDurationTenHoursPenalty() {
        let entry = DailyEntry(sleepHours: 10.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 45)
    }

    func testDurationTwelveHoursPenalty() {
        let entry = DailyEntry(sleepHours: 12.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 35)
    }

    func testDurationOversleepFloorAt25() {
        let entry = DailyEntry(sleepHours: 20.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.durationPoints, 25)
    }

    // MARK: - Consistency Points (30 max)

    func testConsistencyFewerThanThreeNightsGivesBenefitOfDoubt() {
        let entry = DailyEntry(sleepHours: 8.0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.consistencyPoints, 20)
    }

    // MARK: - Interruption Points (20 max)

    func testNoInterruptionsFullPoints() {
        let entry = DailyEntry(sleepHours: 8.0, sleepAwakeMinutes: 0, sleepInterruptionCount: 0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.interruptionPoints, 20)
    }

    func testFiveInterruptionsZeroPoints() {
        let entry = DailyEntry(sleepHours: 8.0, sleepInterruptionCount: 5)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.interruptionPoints, 0)
    }

    func testHighAwakeMinutesZeroPoints() {
        let entry = DailyEntry(sleepHours: 8.0, sleepAwakeMinutes: 100, sleepInterruptionCount: 0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.interruptionPoints, 0)
    }

    func testInterruptionPointsFloorAtZero() {
        let entry = DailyEntry(sleepHours: 8.0, sleepAwakeMinutes: 200, sleepInterruptionCount: 10)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.interruptionPoints, 0)
    }

    // MARK: - Computed Total

    func testTotalIsComputedFromComponents() {
        let entry = DailyEntry(sleepHours: 8.0, sleepAwakeMinutes: 0, sleepInterruptionCount: 0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertEqual(score.total, score.durationPoints + score.consistencyPoints + score.interruptionPoints)
    }

    func testTotalCappedAt100() {
        let entry = DailyEntry(sleepHours: 8.0, sleepAwakeMinutes: 0, sleepInterruptionCount: 0)
        let score = SleepScoreService.computeScore(for: entry, recentEntries: [])!
        XCTAssertLessThanOrEqual(score.total, 100)
    }

    // MARK: - Nil Input

    func testComputeScoreReturnsNilWhenSleepHoursNil() {
        let entry = DailyEntry()
        XCTAssertNil(SleepScoreService.computeScore(for: entry, recentEntries: []))
    }

    // MARK: - Label

    func testLabelForLow() {
        XCTAssertEqual(SleepScoreService.label(for: 0), "Low")
        XCTAssertEqual(SleepScoreService.label(for: 40), "Low")
    }

    func testLabelForFair() {
        XCTAssertEqual(SleepScoreService.label(for: 41), "Fair")
        XCTAssertEqual(SleepScoreService.label(for: 60), "Fair")
    }

    func testLabelForGood() {
        XCTAssertEqual(SleepScoreService.label(for: 61), "Good")
        XCTAssertEqual(SleepScoreService.label(for: 80), "Good")
    }

    func testLabelForExcellent() {
        XCTAssertEqual(SleepScoreService.label(for: 81), "Excellent")
        XCTAssertEqual(SleepScoreService.label(for: 100), "Excellent")
    }
}
