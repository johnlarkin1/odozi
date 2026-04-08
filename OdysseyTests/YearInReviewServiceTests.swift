@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class YearInReviewServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeEntry(
        year: Int,
        month: Int,
        day: Int,
        feeling: Int? = 5,
        sleepQuality: Int? = 5,
        singleWordFeeling: String = "",
        journalEntry: String = "Test",
        city: String? = nil,
        stepCount: Int? = nil,
        drinks: Int? = 0,
        feelingColorHex: String? = "#FF0000",
        gratitude: String = ""
    ) -> DailyEntry {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        return DailyEntry(
            date: date,
            feeling: feeling,
            singleWordFeeling: singleWordFeeling,
            feelingColorHex: feelingColorHex,
            sleepQuality: sleepQuality,
            gratitude: gratitude,
            journalEntry: journalEntry,
            drinks: drinks,
            city: city,
            stepCount: stepCount
        )
    }

    private func insertEntries(_ entries: [DailyEntry]) throws {
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
    }

    // MARK: - Empty Data

    func testGenerateWithNoEntries() {
        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)

        XCTAssertEqual(data.year, 2025)
        XCTAssertEqual(data.totalEntries, 0)
        XCTAssertEqual(data.averageMood, 0)
        XCTAssertEqual(data.averageSleep, 0)
        XCTAssertEqual(data.totalSteps, 0)
        XCTAssertEqual(data.totalDrinks, 0)
        XCTAssertEqual(data.longestStreak, 0)
        XCTAssertNil(data.bestDay)
        XCTAssertTrue(data.topCities.isEmpty)
        XCTAssertTrue(data.feelingWordCloud.isEmpty)
        XCTAssertTrue(data.allColors.isEmpty)
        XCTAssertTrue(data.topGratitudes.isEmpty)
    }

    // MARK: - Basic Aggregation

    func testTotalEntriesCountsOnlyWithPromptData() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, journalEntry: "Has data"),
            makeEntry(year: 2025, month: 1, day: 2, feeling: nil, sleepQuality: nil, journalEntry: "") // No prompt data
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.totalEntries, 1) // Only the one with journal entry
    }

    func testAverageMoodCalculation() throws {
        let entries = [
            makeEntry(year: 2025, month: 3, day: 1, feeling: 8, journalEntry: "Great"),
            makeEntry(year: 2025, month: 3, day: 2, feeling: 6, journalEntry: "Good"),
            makeEntry(year: 2025, month: 3, day: 3, feeling: 4, journalEntry: "Meh")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.averageMood, 6.0, accuracy: 0.01)
    }

    func testAverageSleepCalculation() throws {
        let entries = [
            makeEntry(year: 2025, month: 3, day: 1, sleepQuality: 9, journalEntry: "a"),
            makeEntry(year: 2025, month: 3, day: 2, sleepQuality: 7, journalEntry: "b")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.averageSleep, 8.0, accuracy: 0.01)
    }

    // MARK: - Totals

    func testTotalSteps() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, stepCount: 5000),
            makeEntry(year: 2025, month: 1, day: 2, stepCount: 8000),
            makeEntry(year: 2025, month: 1, day: 3) // nil steps
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.totalSteps, 13000)
    }

    func testTotalDrinks() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, drinks: 2),
            makeEntry(year: 2025, month: 1, day: 2, drinks: 1),
            makeEntry(year: 2025, month: 1, day: 3, drinks: 0)
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.totalDrinks, 3)
    }

    // MARK: - Top Cities

    func testTopCities() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, city: "Chicago"),
            makeEntry(year: 2025, month: 1, day: 2, city: "Chicago"),
            makeEntry(year: 2025, month: 1, day: 3, city: "New York"),
            makeEntry(year: 2025, month: 1, day: 4) // nil city
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.topCities.count, 2)
        XCTAssertEqual(data.topCities.first?.city, "Chicago")
        XCTAssertEqual(data.topCities.first?.count, 2)
    }

    // MARK: - Feeling Word Cloud

    func testFeelingWordCloud() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, singleWordFeeling: "Happy", journalEntry: "a"),
            makeEntry(year: 2025, month: 1, day: 2, singleWordFeeling: "happy", journalEntry: "b"),
            makeEntry(year: 2025, month: 1, day: 3, singleWordFeeling: "Calm", journalEntry: "c")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.feelingWordCloud.count, 2)
        XCTAssertEqual(data.feelingWordCloud.first?.word, "happy")
        XCTAssertEqual(data.feelingWordCloud.first?.count, 2)
    }

    // MARK: - Longest Streak

    func testLongestStreak() throws {
        // 3 consecutive days
        let entries = [
            makeEntry(year: 2025, month: 6, day: 1, journalEntry: "a"),
            makeEntry(year: 2025, month: 6, day: 2, journalEntry: "b"),
            makeEntry(year: 2025, month: 6, day: 3, journalEntry: "c"),
            // gap
            makeEntry(year: 2025, month: 6, day: 5, journalEntry: "d"),
            makeEntry(year: 2025, month: 6, day: 6, journalEntry: "e")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.longestStreak, 3)
    }

    // MARK: - Best Day

    func testBestDayIsHighestMood() throws {
        let entries = [
            makeEntry(year: 2025, month: 2, day: 1, feeling: 5, journalEntry: "ok"),
            makeEntry(year: 2025, month: 2, day: 2, feeling: 10, journalEntry: "amazing"),
            makeEntry(year: 2025, month: 2, day: 3, feeling: 7, journalEntry: "good")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertNotNil(data.bestDay)
        XCTAssertEqual(data.bestDay?.feeling, 10)
    }

    // MARK: - Mood By Month

    func testMoodByMonthHas12Entries() throws {
        let entries = [makeEntry(year: 2025, month: 3, day: 1, feeling: 7, journalEntry: "March")]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.moodByMonth.count, 12)
    }

    func testMoodByMonthCalculatesAverageForMonth() throws {
        let entries = [
            makeEntry(year: 2025, month: 3, day: 1, feeling: 8, journalEntry: "a"),
            makeEntry(year: 2025, month: 3, day: 15, feeling: 6, journalEntry: "b")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        // March is index 2 (0-based)
        let marchMood = data.moodByMonth[2].avgMood
        XCTAssertEqual(marchMood, 7.0, accuracy: 0.01)
    }

    func testMoodByMonthZeroForEmptyMonths() throws {
        let entries = [makeEntry(year: 2025, month: 1, day: 1, feeling: 8, journalEntry: "Jan only")]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        // February (index 1) should be 0
        XCTAssertEqual(data.moodByMonth[1].avgMood, 0)
    }

    // MARK: - Colors & Gratitudes

    func testAllColorsExcludesWhite() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, feelingColorHex: "#FF0000"),
            makeEntry(year: 2025, month: 1, day: 2, feelingColorHex: nil) // No color = excluded
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.allColors, ["#FF0000"])
    }

    func testTopGratitudes() throws {
        let entries = [
            makeEntry(year: 2025, month: 1, day: 1, journalEntry: "a", gratitude: "Family"),
            makeEntry(year: 2025, month: 1, day: 2, journalEntry: "b", gratitude: "Health"),
            makeEntry(year: 2025, month: 1, day: 3, journalEntry: "c", gratitude: "") // empty, excluded
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.topGratitudes.count, 2)
        XCTAssertTrue(data.topGratitudes.contains("Family"))
        XCTAssertTrue(data.topGratitudes.contains("Health"))
    }

    // MARK: - completionPercentage

    func testCompletionPercentage() throws {
        // Create entries for first 10 days of 2025
        var entries: [DailyEntry] = []
        for day in 1 ... 10 {
            entries.append(makeEntry(year: 2025, month: 1, day: day, journalEntry: "Day \(day)"))
        }
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        let expected = (10.0 / 365.0) * 100.0
        XCTAssertEqual(data.completionPercentage, expected, accuracy: 0.1)
    }

    // MARK: - Year Filtering

    func testOnlyIncludesEntriesForRequestedYear() throws {
        let entries = [
            makeEntry(year: 2024, month: 12, day: 31, feeling: 3, journalEntry: "Last year"),
            makeEntry(year: 2025, month: 1, day: 1, feeling: 9, journalEntry: "This year"),
            makeEntry(year: 2026, month: 1, day: 1, feeling: 2, journalEntry: "Next year")
        ]
        try insertEntries(entries)

        let service = YearInReviewService(modelContext: context)
        let data = service.generate(for: 2025)
        XCTAssertEqual(data.totalEntries, 1)
        XCTAssertEqual(data.averageMood, 9.0, accuracy: 0.01)
    }
}
