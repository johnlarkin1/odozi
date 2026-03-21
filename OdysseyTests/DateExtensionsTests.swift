@testable import Odyssey
import XCTest

final class DateExtensionsTests: XCTestCase {
    // MARK: - startOfDay

    func testStartOfDayStripsTime() {
        let date = Calendar.current.date(bySettingHour: 14, minute: 30, second: 45, of: Date())!
        let startOfDay = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: startOfDay)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testStartOfDayPreservesDate() {
        let date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
        let startOfDay = date.startOfDay
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: startOfDay), cal.component(.year, from: date))
        XCTAssertEqual(cal.component(.month, from: startOfDay), cal.component(.month, from: date))
        XCTAssertEqual(cal.component(.day, from: startOfDay), cal.component(.day, from: date))
    }

    // MARK: - isToday

    func testIsTodayReturnsTrueForNow() {
        XCTAssertTrue(Date().isToday)
    }

    func testIsTodayReturnsFalseForYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(yesterday.isToday)
    }

    // MARK: - isYesterday

    func testIsYesterdayReturnsTrueForYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(yesterday.isYesterday)
    }

    func testIsYesterdayReturnsFalseForToday() {
        XCTAssertFalse(Date().isYesterday)
    }

    func testIsYesterdayReturnsFalseForTwoDaysAgo() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertFalse(twoDaysAgo.isYesterday)
    }

    // MARK: - dayOfWeek

    func testDayOfWeekReturnsFullDayName() {
        let knownDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let dayName = Date().dayOfWeek
        XCTAssertTrue(knownDayNames.contains(dayName), "Expected a full day name, got: \(dayName)")
    }

    // MARK: - monthYear

    func testMonthYearFormat() {
        // Create a known date: January 15, 2025
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.monthYear, "January 2025")
    }

    // MARK: - dayNumber

    func testDayNumberReturnsCorrectDay() {
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 22
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.dayNumber, 22)
    }

    func testDayNumberFirstOfMonth() {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 1
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.dayNumber, 1)
    }

    // MARK: - daysAgo

    func testDaysAgoSubtractsDays() {
        let now = Date()
        let threeDaysAgo = now.daysAgo(3)
        let daysBetween = Calendar.current.dateComponents([.day], from: threeDaysAgo, to: now).day!
        XCTAssertEqual(daysBetween, 3)
    }

    func testDaysAgoZeroReturnsSameDay() {
        let now = Date()
        let same = now.daysAgo(0)
        XCTAssertTrue(Calendar.current.isDate(now, inSameDayAs: same))
    }

    // MARK: - shortFormatted

    func testShortFormattedReturnsNonEmptyString() {
        let formatted = Date().shortFormatted
        XCTAssertFalse(formatted.isEmpty)
    }
}
