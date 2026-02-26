import XCTest
import SwiftData
@testable import Odyssey

@MainActor
final class InsightsViewModelTests: XCTestCase {

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
        feelingColorHex: String = "#FF0000"
    ) -> DailyEntry {
        let date = Calendar.current.startOfDay(for: Date().daysAgo(daysAgo))
        return DailyEntry(
            date: date,
            feeling: feeling,
            singleWordFeeling: singleWordFeeling,
            feelingColorHex: feelingColorHex,
            sleepQuality: sleepQuality,
            journalEntry: journalEntry
        )
    }

    private func populateAndLoad(_ vm: InsightsViewModel, entries: [DailyEntry]) throws {
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
        vm.loadEntries()
    }

    // MARK: - loadEntries

    func testLoadEntriesPopulatesArray() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 1)]
        try populateAndLoad(vm, entries: entries)
        XCTAssertEqual(vm.entries.count, 2)
    }

    func testLoadEntriesEmptyWhenNoData() {
        let vm = InsightsViewModel(modelContext: context)
        vm.loadEntries()
        XCTAssertTrue(vm.entries.isEmpty)
    }

    // MARK: - filteredEntries

    func testFilteredEntriesDefaultsToMonth() throws {
        let vm = InsightsViewModel(modelContext: context)
        // Entry within a month and one outside
        let recent = makeEntry(daysAgo: 5)
        let old = makeEntry(daysAgo: 60)
        try populateAndLoad(vm, entries: [recent, old])

        XCTAssertEqual(vm.dateRange, .month)
        XCTAssertEqual(vm.filteredEntries.count, 1) // Only the recent one
    }

    func testFilteredEntriesAllTimeIncludesAll() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 100), makeEntry(daysAgo: 200)]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertEqual(vm.filteredEntries.count, 3)
    }

    func testFilteredEntriesSortedByDateAscending() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 3), makeEntry(daysAgo: 7)]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        let dates = vm.filteredEntries.map { $0.date }
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - averageMood

    func testAverageMoodCalculation() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [
            makeEntry(daysAgo: 0, feeling: 8, journalEntry: "Good"),
            makeEntry(daysAgo: 1, feeling: 6, journalEntry: "Okay"),
            makeEntry(daysAgo: 2, feeling: 4, journalEntry: "Meh"),
        ]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertEqual(vm.averageMood, 6.0, accuracy: 0.01) // (8+6+4)/3
    }

    func testAverageMoodZeroWhenEmpty() {
        let vm = InsightsViewModel(modelContext: context)
        vm.loadEntries()
        XCTAssertEqual(vm.averageMood, 0)
    }

    func testAverageMoodExcludesEntriesWithoutPromptData() throws {
        let vm = InsightsViewModel(modelContext: context)
        let withData = makeEntry(daysAgo: 0, feeling: 8, journalEntry: "Has data")
        let withoutData = DailyEntry(
            date: Calendar.current.startOfDay(for: Date().daysAgo(1)),
            feeling: 2,
            singleWordFeeling: "",
            journalEntry: ""
        )
        try populateAndLoad(vm, entries: [withData, withoutData])
        vm.dateRange = .allTime

        XCTAssertEqual(vm.averageMood, 8.0, accuracy: 0.01)
    }

    // MARK: - averageSleep

    func testAverageSleepCalculation() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [
            makeEntry(daysAgo: 0, sleepQuality: 9, journalEntry: "Well rested"),
            makeEntry(daysAgo: 1, sleepQuality: 7, journalEntry: "Okay sleep"),
        ]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertEqual(vm.averageSleep, 8.0, accuracy: 0.01) // (9+7)/2
    }

    // MARK: - longestStreak

    func testLongestStreakWithConsecutiveDays() throws {
        let vm = InsightsViewModel(modelContext: context)
        // 5 consecutive days
        var entries: [DailyEntry] = []
        for i in 0..<5 {
            entries.append(makeEntry(daysAgo: i, journalEntry: "Day \(i)"))
        }
        try populateAndLoad(vm, entries: entries)

        XCTAssertEqual(vm.longestStreak, 5)
    }

    func testLongestStreakWithGap() throws {
        let vm = InsightsViewModel(modelContext: context)
        // 3 consecutive, gap, 2 consecutive
        let entries = [
            makeEntry(daysAgo: 0, journalEntry: "a"),
            makeEntry(daysAgo: 1, journalEntry: "b"),
            makeEntry(daysAgo: 2, journalEntry: "c"),
            // gap at daysAgo: 3
            makeEntry(daysAgo: 4, journalEntry: "d"),
            makeEntry(daysAgo: 5, journalEntry: "e"),
        ]
        try populateAndLoad(vm, entries: entries)

        XCTAssertEqual(vm.longestStreak, 3)
    }

    func testLongestStreakZeroWhenNoEntries() {
        let vm = InsightsViewModel(modelContext: context)
        vm.loadEntries()
        XCTAssertEqual(vm.longestStreak, 0)
    }

    // MARK: - topFeelingWords

    func testTopFeelingWordsCountsCorrectly() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [
            makeEntry(daysAgo: 0, singleWordFeeling: "Happy", journalEntry: "a"),
            makeEntry(daysAgo: 1, singleWordFeeling: "happy", journalEntry: "b"), // same word, different case
            makeEntry(daysAgo: 2, singleWordFeeling: "Calm", journalEntry: "c"),
        ]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        let words = vm.topFeelingWords
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words.first?.word, "happy")
        XCTAssertEqual(words.first?.count, 2)
    }

    func testTopFeelingWordsSkipsEmpty() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [
            makeEntry(daysAgo: 0, singleWordFeeling: "", journalEntry: "a"),
            makeEntry(daysAgo: 1, singleWordFeeling: "Peaceful", journalEntry: "b"),
        ]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertEqual(vm.topFeelingWords.count, 1)
        XCTAssertEqual(vm.topFeelingWords.first?.word, "peaceful")
    }

    func testTopFeelingWordsLimitedToTen() throws {
        let vm = InsightsViewModel(modelContext: context)
        var entries: [DailyEntry] = []
        let words = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]
        for (i, word) in words.enumerated() {
            entries.append(makeEntry(daysAgo: i, singleWordFeeling: word, journalEntry: "x"))
        }
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertLessThanOrEqual(vm.topFeelingWords.count, 10)
    }

    // MARK: - feelingColors

    func testFeelingColorsExcludesWhite() throws {
        let vm = InsightsViewModel(modelContext: context)
        let entries = [
            makeEntry(daysAgo: 0, feelingColorHex: "#FF0000"),
            makeEntry(daysAgo: 1, feelingColorHex: "#FFFFFF"), // Should be excluded
            makeEntry(daysAgo: 2, feelingColorHex: "#00FF00"),
        ]
        try populateAndLoad(vm, entries: entries)
        vm.dateRange = .allTime

        XCTAssertEqual(vm.feelingColors.count, 2)
        XCTAssertFalse(vm.feelingColors.contains("#FFFFFF"))
    }
}
