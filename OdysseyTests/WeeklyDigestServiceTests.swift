@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class WeeklyDigestServiceTests: XCTestCase {
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
        daysAgo: Int = 0,
        feeling: Int = 5,
        sleepQuality: Int = 5,
        singleWordFeeling: String = "",
        journalEntry: String = "Test",
        drinks: Int = 0,
        stepCount: Int? = nil,
        sleepHours: Double? = nil,
        screenTimeSeconds: Double? = nil
    ) -> DailyEntry {
        let date = Calendar.current.startOfDay(for: Date().daysAgo(daysAgo))
        return DailyEntry(
            date: date,
            feeling: feeling,
            singleWordFeeling: singleWordFeeling,
            sleepQuality: sleepQuality,
            journalEntry: journalEntry,
            drinks: drinks,
            stepCount: stepCount,
            sleepHours: sleepHours,
            screenTimeSeconds: screenTimeSeconds
        )
    }

    private func insertEntries(_ entries: [DailyEntry]) throws {
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
    }

    private func computeDigest(endDate: Date = Date()) -> WeeklyDigestData {
        WeeklyDigestService.computeDigest(context: context, endDate: endDate)
    }

    // MARK: - Empty Data

    func testEmptyDigestWhenNoEntries() {
        let digest = computeDigest()

        XCTAssertEqual(digest.daysJournaled, 0)
        XCTAssertEqual(digest.totalDays, 7)
        XCTAssertEqual(digest.averageMood, 0)
        XCTAssertNil(digest.previousWeekAverageMood)
        XCTAssertNil(digest.moodTrendDelta)
        XCTAssertNil(digest.topEmotion)
        XCTAssertEqual(digest.totalSteps, 0)
        XCTAssertEqual(digest.totalDrinks, 0)
        XCTAssertNil(digest.averageSleepHours)
        XCTAssertNil(digest.averageScreenTimeHours)
        XCTAssertFalse(digest.hasData)
    }

    func testEmptyFactoryMethod() {
        let digest = WeeklyDigestData.empty(endDate: Date())

        XCTAssertEqual(digest.daysJournaled, 0)
        XCTAssertEqual(digest.totalDays, 7)
        XCTAssertFalse(digest.hasData)
        XCTAssertEqual(digest.moodTrendSymbol, "")
    }

    // MARK: - Days Journaled

    func testDaysJournaledCountsOnlyPromptEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, journalEntry: "Has data"),
            makeEntry(daysAgo: 1, journalEntry: "Also has data"),
            makeEntry(daysAgo: 2, singleWordFeeling: "", journalEntry: ""), // No prompt data
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.daysJournaled, 2)
        XCTAssertTrue(digest.hasData)
    }

    func testDaysJournaledExcludesEntriesOutsideWeek() throws {
        let entries = [
            makeEntry(daysAgo: 0, journalEntry: "This week"),
            makeEntry(daysAgo: 10, journalEntry: "Outside week"), // >7 days ago
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.daysJournaled, 1)
    }

    // MARK: - Average Mood

    func testAverageMoodCalculation() throws {
        let entries = [
            makeEntry(daysAgo: 0, feeling: 8, journalEntry: "Great"),
            makeEntry(daysAgo: 1, feeling: 6, journalEntry: "Good"),
            makeEntry(daysAgo: 2, feeling: 4, journalEntry: "Meh"),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.averageMood, 6.0, accuracy: 0.01)
    }

    func testAverageMoodExcludesNonPromptEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, feeling: 8, journalEntry: "Has data"),
            makeEntry(daysAgo: 1, feeling: 2, singleWordFeeling: "", journalEntry: ""),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.averageMood, 8.0, accuracy: 0.01)
    }

    // MARK: - Mood Trend (WoW)

    func testMoodTrendWithPreviousWeek() throws {
        // Previous week: avg mood 5
        let prevEntries = [
            makeEntry(daysAgo: 10, feeling: 4, journalEntry: "a"),
            makeEntry(daysAgo: 11, feeling: 6, journalEntry: "b"),
        ]
        // Current week: avg mood 8
        let currentEntries = [
            makeEntry(daysAgo: 0, feeling: 7, journalEntry: "c"),
            makeEntry(daysAgo: 1, feeling: 9, journalEntry: "d"),
        ]
        try insertEntries(prevEntries + currentEntries)

        let digest = computeDigest()
        XCTAssertNotNil(digest.previousWeekAverageMood)
        XCTAssertEqual(digest.previousWeekAverageMood!, 5.0, accuracy: 0.01)
        XCTAssertEqual(digest.moodTrendDelta!, 3.0, accuracy: 0.01)
    }

    func testMoodTrendNilWhenNoPreviousWeek() throws {
        let entries = [makeEntry(daysAgo: 0, feeling: 7, journalEntry: "Only this week")]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertNil(digest.previousWeekAverageMood)
        XCTAssertNil(digest.moodTrendDelta)
    }

    // MARK: - Mood Trend Symbol

    func testMoodTrendSymbolUp() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 1, totalDays: 7, averageMood: 8,
            previousWeekAverageMood: 5, moodTrendDelta: 0.5,
            topEmotion: nil, currentStreak: 0, averageSleepQuality: nil,
            totalSteps: 0, totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )
        XCTAssertEqual(data.moodTrendSymbol, "↑")
    }

    func testMoodTrendSymbolDown() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 1, totalDays: 7, averageMood: 4,
            previousWeekAverageMood: 7, moodTrendDelta: -0.5,
            topEmotion: nil, currentStreak: 0, averageSleepQuality: nil,
            totalSteps: 0, totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )
        XCTAssertEqual(data.moodTrendSymbol, "↓")
    }

    func testMoodTrendSymbolFlat() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 1, totalDays: 7, averageMood: 7,
            previousWeekAverageMood: 7, moodTrendDelta: 0.1,
            topEmotion: nil, currentStreak: 0, averageSleepQuality: nil,
            totalSteps: 0, totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )
        XCTAssertEqual(data.moodTrendSymbol, "→")
    }

    func testMoodTrendSymbolEmptyWhenNoDelta() {
        let data = WeeklyDigestData.empty(endDate: Date())
        XCTAssertEqual(data.moodTrendSymbol, "")
    }

    // MARK: - Top Emotion

    func testTopEmotionMostFrequent() throws {
        let entries = [
            makeEntry(daysAgo: 0, singleWordFeeling: "Happy", journalEntry: "a"),
            makeEntry(daysAgo: 1, singleWordFeeling: "happy", journalEntry: "b"),
            makeEntry(daysAgo: 2, singleWordFeeling: "Calm", journalEntry: "c"),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        // "Happy" and "happy" should group together (case-insensitive)
        XCTAssertNotNil(digest.topEmotion)
        XCTAssertEqual(digest.topEmotion?.lowercased(), "happy")
    }

    func testTopEmotionNilWhenNoFeelings() throws {
        let entries = [
            makeEntry(daysAgo: 0, singleWordFeeling: "", journalEntry: "No feeling word"),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertNil(digest.topEmotion)
    }

    func testTopEmotionSkipsEmptyStrings() throws {
        let entries = [
            makeEntry(daysAgo: 0, singleWordFeeling: "", journalEntry: "a"),
            makeEntry(daysAgo: 1, singleWordFeeling: "Grateful", journalEntry: "b"),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.topEmotion, "Grateful")
    }

    // MARK: - Sleep Quality

    func testAverageSleepQuality() throws {
        let entries = [
            makeEntry(daysAgo: 0, sleepQuality: 9, journalEntry: "a"),
            makeEntry(daysAgo: 1, sleepQuality: 7, journalEntry: "b"),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertNotNil(digest.averageSleepQuality)
        XCTAssertEqual(digest.averageSleepQuality!, 8.0, accuracy: 0.01)
    }

    func testAverageSleepQualityNilWhenNoPromptEntries() {
        let digest = computeDigest()
        XCTAssertNil(digest.averageSleepQuality)
    }

    // MARK: - Steps

    func testTotalStepsAggregatesAllEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, journalEntry: "a", stepCount: 5000),
            makeEntry(daysAgo: 1, stepCount: 8000), // background-only also counts
            makeEntry(daysAgo: 2, journalEntry: "b", stepCount: nil),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.totalSteps, 13000)
    }

    func testTotalStepsZeroWhenNoStepData() {
        let digest = computeDigest()
        XCTAssertEqual(digest.totalSteps, 0)
    }

    // MARK: - Drinks

    func testTotalDrinksFromPromptEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, journalEntry: "a", drinks: 2),
            makeEntry(daysAgo: 1, journalEntry: "b", drinks: 1),
            makeEntry(daysAgo: 2, journalEntry: "c", drinks: 0),
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertEqual(digest.totalDrinks, 3)
    }

    // MARK: - Sleep Hours

    func testAverageSleepHours() throws {
        let entries = [
            makeEntry(daysAgo: 0, sleepHours: 7.0),
            makeEntry(daysAgo: 1, sleepHours: 8.0),
            makeEntry(daysAgo: 2, sleepHours: nil), // excluded from avg
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertNotNil(digest.averageSleepHours)
        XCTAssertEqual(digest.averageSleepHours!, 7.5, accuracy: 0.01)
    }

    func testAverageSleepHoursNilWhenNoData() {
        let digest = computeDigest()
        XCTAssertNil(digest.averageSleepHours)
    }

    // MARK: - Screen Time

    func testAverageScreenTimeHours() throws {
        let entries = [
            makeEntry(daysAgo: 0, screenTimeSeconds: 7200), // 2h
            makeEntry(daysAgo: 1, screenTimeSeconds: 10800), // 3h
        ]
        try insertEntries(entries)

        let digest = computeDigest()
        XCTAssertNotNil(digest.averageScreenTimeHours)
        XCTAssertEqual(digest.averageScreenTimeHours!, 2.5, accuracy: 0.01)
    }

    func testAverageScreenTimeNilWhenNoData() {
        let digest = computeDigest()
        XCTAssertNil(digest.averageScreenTimeHours)
    }

    // MARK: - Date Range

    func testWeekStartAndEndDates() {
        let endDate = Date()
        let digest = WeeklyDigestService.computeDigest(context: context, endDate: endDate)
        let calendar = Calendar.current

        let expectedStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!
        XCTAssertEqual(calendar.startOfDay(for: digest.weekStartDate), expectedStart)
        XCTAssertEqual(calendar.startOfDay(for: digest.weekEndDate), calendar.startOfDay(for: endDate))
    }

    // MARK: - formatDigestBody

    func testFormatDigestBodyWithData() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 5, totalDays: 7, averageMood: 7.2,
            previousWeekAverageMood: 6.5, moodTrendDelta: 0.7,
            topEmotion: "Grateful", currentStreak: 3,
            averageSleepQuality: 7.0, totalSteps: 40000,
            totalDrinks: 2, averageSleepHours: 7.5,
            averageScreenTimeHours: 4.0
        )

        let body = WeeklyDigestNotificationManager.formatDigestBody(data)
        XCTAssertTrue(body.contains("5/7"))
        XCTAssertTrue(body.contains("7.2/10"))
        XCTAssertTrue(body.contains("+0.7"))
        XCTAssertTrue(body.contains("3-day streak"))
        XCTAssertTrue(body.contains("Grateful"))
    }

    func testFormatDigestBodyNoData() {
        let data = WeeklyDigestData.empty(endDate: Date())
        let body = WeeklyDigestNotificationManager.formatDigestBody(data)
        XCTAssertTrue(body.contains("Start journaling"))
    }

    func testFormatDigestBodyNegativeTrend() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 3, totalDays: 7, averageMood: 5.0,
            previousWeekAverageMood: 7.0, moodTrendDelta: -2.0,
            topEmotion: nil, currentStreak: 0,
            averageSleepQuality: nil, totalSteps: 0,
            totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )

        let body = WeeklyDigestNotificationManager.formatDigestBody(data)
        XCTAssertTrue(body.contains("-2.0"))
        XCTAssertTrue(body.contains("3/7"))
    }

    func testFormatDigestBodyNoTrend() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 2, totalDays: 7, averageMood: 6.0,
            previousWeekAverageMood: nil, moodTrendDelta: nil,
            topEmotion: nil, currentStreak: 0,
            averageSleepQuality: nil, totalSteps: 0,
            totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )

        let body = WeeklyDigestNotificationManager.formatDigestBody(data)
        XCTAssertTrue(body.contains("6.0/10"))
        XCTAssertFalse(body.contains("vs last week"))
    }

    func testFormatDigestBodyNoStreak() {
        let data = WeeklyDigestData(
            weekStartDate: Date(), weekEndDate: Date(),
            daysJournaled: 1, totalDays: 7, averageMood: 5.0,
            previousWeekAverageMood: nil, moodTrendDelta: nil,
            topEmotion: nil, currentStreak: 0,
            averageSleepQuality: nil, totalSteps: 0,
            totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )

        let body = WeeklyDigestNotificationManager.formatDigestBody(data)
        XCTAssertFalse(body.contains("streak"))
    }
}
