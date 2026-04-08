@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class DailyEntryViewModelTests: XCTestCase {
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
        journalEntry: String = "Test",
        singleWordFeeling: String = "okay"
    ) -> DailyEntry {
        let date = Calendar.current.startOfDay(for: Date().daysAgo(daysAgo))
        return DailyEntry(
            date: date,
            feeling: feeling,
            singleWordFeeling: singleWordFeeling,
            journalEntry: journalEntry
        )
    }

    // MARK: - Initial State

    func testInitialStateNoEntries() {
        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertFalse(vm.hasSubmittedData)
    }

    // MARK: - submitData

    func testSubmitDataCreatesEntry() throws {
        let vm = DailyEntryViewModel(modelContext: context)
        vm.submitData(
            feeling: 7,
            singleWordFeeling: "grateful",
            feelingColorHex: "#4CAF50",
            sleepQuality: 8,
            gratitude: "Health",
            win: "Ran 5k",
            tension: "None",
            journalEntry: "Great day",
            drinks: 1
        )

        XCTAssertTrue(vm.hasSubmittedData)
        XCTAssertEqual(vm.submissionMessage, "Successfully saved today's entry.")

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        let entry = entries.first!
        XCTAssertEqual(entry.feeling, 7)
        XCTAssertEqual(entry.singleWordFeeling, "grateful")
        XCTAssertEqual(entry.feelingColorHex, "#4CAF50")
        XCTAssertEqual(entry.sleepQuality, 8)
        XCTAssertEqual(entry.gratitude, "Health")
        XCTAssertEqual(entry.win, "Ran 5k")
        XCTAssertEqual(entry.tension, "None")
        XCTAssertEqual(entry.journalEntry, "Great day")
        XCTAssertEqual(entry.drinks, 1)
    }

    func testSubmitDataUpdatesExistingEntry() throws {
        // Create an existing entry for today
        let today = Calendar.current.startOfDay(for: Date())
        let existing = DailyEntry(date: today, feeling: 3, journalEntry: "Bad day")
        context.insert(existing)
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        vm.submitData(
            feeling: 8,
            singleWordFeeling: "better",
            feelingColorHex: "#FFFFFF",
            sleepQuality: 7,
            gratitude: "Second chance",
            win: "Recovered",
            tension: "",
            journalEntry: "Much better now",
            drinks: 0
        )

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1, "Should update, not create a second entry")
        XCTAssertEqual(entries.first?.feeling, 8)
        XCTAssertEqual(entries.first?.journalEntry, "Much better now")
    }

    // MARK: - fetchTodayEntry

    func testFetchTodayEntryReturnsNilWhenEmpty() {
        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertNil(vm.fetchTodayEntry())
    }

    func testFetchTodayEntryReturnsTodaysEntry() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let entry = DailyEntry(date: today, feeling: 7, journalEntry: "Hello")
        context.insert(entry)
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        let fetched = vm.fetchTodayEntry()
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.feeling, 7)
    }

    // MARK: - fetchEntry(for:)

    func testFetchEntryForSpecificDate() throws {
        let threeDaysAgo = Calendar.current.startOfDay(for: Date().daysAgo(3))
        let entry = DailyEntry(date: threeDaysAgo, feeling: 6, journalEntry: "Past entry")
        context.insert(entry)
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        let fetched = vm.fetchEntry(for: threeDaysAgo)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.journalEntry, "Past entry")
    }

    func testFetchEntryForMissingDate() {
        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertNil(vm.fetchEntry(for: Date().daysAgo(100)))
    }

    // MARK: - fetchEntries(from:to:)

    func testFetchEntriesInRange() throws {
        for i in 0 ..< 5 {
            let entry = makeEntry(daysAgo: i)
            context.insert(entry)
        }
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        let start = Date().daysAgo(3)
        let end = Date()
        let entries = vm.fetchEntries(from: start, to: end)
        XCTAssertEqual(entries.count, 4) // today, 1 day ago, 2 days ago, 3 days ago
    }

    // MARK: - fetchAllEntries

    func testFetchAllEntries() throws {
        for i in 0 ..< 3 {
            context.insert(makeEntry(daysAgo: i))
        }
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        let entries = vm.fetchAllEntries()
        XCTAssertEqual(entries.count, 3)
    }

    // MARK: - currentStreak

    func testCurrentStreakWithConsecutiveDays() throws {
        // Create entries for today, yesterday, and 2 days ago
        for i in 0 ..< 3 {
            context.insert(makeEntry(daysAgo: i, journalEntry: "Day \(i)"))
        }
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStreak, 3)
    }

    func testCurrentStreakBreaksOnGap() throws {
        // Today and yesterday, then skip a day, then 3 days ago
        context.insert(makeEntry(daysAgo: 0, journalEntry: "Today"))
        context.insert(makeEntry(daysAgo: 1, journalEntry: "Yesterday"))
        context.insert(makeEntry(daysAgo: 3, journalEntry: "Three days ago"))
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStreak, 2)
    }

    func testCurrentStreakCountsFromYesterdayWhenTodayMissing() throws {
        context.insert(makeEntry(daysAgo: 1, journalEntry: "Yesterday"))
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        // Streak is forgiving: if today isn't filled in yet, it counts from yesterday
        XCTAssertEqual(vm.currentStreak, 1)
    }

    func testCurrentStreakRequiresPromptData() throws {
        // Entry for today with no prompt data
        let emptyEntry = DailyEntry(
            date: Calendar.current.startOfDay(for: Date()),
            feeling: 5,
            singleWordFeeling: "",
            journalEntry: ""
        )
        context.insert(emptyEntry)
        try context.save()

        let vm = DailyEntryViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStreak, 0)
    }
}
