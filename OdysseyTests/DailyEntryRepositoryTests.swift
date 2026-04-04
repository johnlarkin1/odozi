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
}
