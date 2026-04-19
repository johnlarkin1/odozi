@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class DailyEntryRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: DailyEntryRepository!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        repository = DailyEntryRepository(context: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        repository = nil
    }

    // MARK: - fetchOrCreate(for:)

    func testFetchOrCreateCreatesNewEntry() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let entry = try repository.fetchOrCreate(for: date)
        XCTAssertEqual(entry.date, date)
    }

    func testFetchOrCreateReturnsSameEntryOnSecondCall() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let first = try repository.fetchOrCreate(for: date)
        first.feeling = 8
        let second = try repository.fetchOrCreate(for: date)
        XCTAssertEqual(second.feeling, 8, "Should return the same entry, not create a new one")
    }

    func testFetchOrCreateNormalizesToStartOfDay() throws {
        // Pass a mid-day date — should still match an entry at start-of-day
        let noon = Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!
        let entry = try repository.fetchOrCreate(for: noon)
        let startOfDay = Calendar.current.startOfDay(for: noon)
        XCTAssertEqual(entry.date, startOfDay)
    }

    func testMultipleDatesCreateSeparateEntries() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let entry1 = try repository.fetchOrCreate(for: today)
        let entry2 = try repository.fetchOrCreate(for: yesterday)
        XCTAssertNotEqual(entry1.date, entry2.date)
    }

    // MARK: - fetchEntry(for:)

    func testFetchEntryReturnsNilWhenNoneExists() throws {
        let result = try repository.fetchEntry(for: Date())
        XCTAssertNil(result)
    }

    func testFetchEntryReturnsExistingEntry() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let created = try repository.fetchOrCreate(for: date)
        created.feeling = 9
        try context.save()

        let fetched = try repository.fetchEntry(for: date)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.feeling, 9)
    }

    // MARK: - fetchOrCreateToday()

    func testFetchOrCreateTodayUsesTodaysDate() throws {
        let entry = try repository.fetchOrCreateToday()
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(entry.date, today)
    }

    func testFetchOrCreateTodayInsertsIntoContext() throws {
        _ = try repository.fetchOrCreateToday()
        try context.save()
        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - Cross-timezone day matching

    func testFetchEntryMatchesEntryAuthoredInDifferentTimezone() throws {
        // Simulate a row created in a different timezone by storing a
        // non-startOfDay timestamp on the same calendar day.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let offsetDate = cal.date(byAdding: .hour, value: 4, to: today)! // +4h = another zone's midnight
        let created = DailyEntry(date: offsetDate)
        created.feeling = 7
        context.insert(created)
        try context.save()

        let fetched = try repository.fetchEntry(for: today)
        XCTAssertNotNil(fetched, "Should match the cross-timezone entry by calendar day")
        XCTAssertEqual(fetched?.feeling, 7)
    }

    func testFetchOrCreateDoesNotDuplicateAcrossTimezoneOffset() throws {
        // Pre-seed with a +4h-offset entry for today.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let offsetDate = cal.date(byAdding: .hour, value: 4, to: today)!
        let original = DailyEntry(date: offsetDate)
        original.feeling = 5
        context.insert(original)
        try context.save()

        let resolved = try repository.fetchOrCreate(for: today)
        XCTAssertTrue(resolved === original, "Should find the existing entry, not create a duplicate")

        let all = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(all.count, 1, "No duplicate should be inserted")
    }

    // MARK: - dedupeByCalendarDay

    func testDedupeMergesTwoEntriesOnSameCalendarDay() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let offsetDate = cal.date(byAdding: .hour, value: 4, to: today)!

        let older = DailyEntry(date: today)
        older.feeling = 6
        older.createdAt = Date().addingTimeInterval(-3600)
        context.insert(older)

        let newer = DailyEntry(date: offsetDate)
        newer.hasUserSubmitted = true
        newer.journalEntry = "submitted content"
        newer.stepCount = 9000
        context.insert(newer)
        try context.save()

        let merged = try repository.dedupeByCalendarDay()
        XCTAssertEqual(merged, 1)

        let all = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(all.count, 1, "Exactly one entry should remain for today")
        let survivor = all[0]
        XCTAssertTrue(survivor.hasUserSubmitted, "User-submitted row should win as primary")
        XCTAssertEqual(survivor.journalEntry, "submitted content")
        XCTAssertEqual(survivor.stepCount, 9000)
        XCTAssertEqual(survivor.feeling, 6, "Non-empty field from the other row should have been merged in")
        XCTAssertEqual(survivor.date, today, "Survivor date should be normalized to startOfDay")
    }

    func testDedupeLeavesDistinctDaysAlone() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        context.insert(DailyEntry(date: today))
        context.insert(DailyEntry(date: yesterday))
        try context.save()

        let merged = try repository.dedupeByCalendarDay()
        XCTAssertEqual(merged, 0)
        let all = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(all.count, 2)
    }
}
