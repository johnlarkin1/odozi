@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class JournalViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: JournalViewModel!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        viewModel = JournalViewModel(modelContext: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        viewModel = nil
    }

    func testLoadEntriesEmpty() {
        viewModel.loadEntries()
        XCTAssertTrue(viewModel.allEntries.isEmpty)
    }

    func testLoadEntriesPopulates() throws {
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 1), makeEntry(daysAgo: 2)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        XCTAssertEqual(viewModel.allEntries.count, 3)
    }

    func testLoadEntriesSortedByDateDescending() throws {
        let entries = [makeEntry(daysAgo: 2), makeEntry(daysAgo: 0), makeEntry(daysAgo: 5)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        let dates = viewModel.allEntries.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testEntryForDateReturnsMatch() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let entry = makeEntry(daysAgo: 0, feeling: 9)
        try insertEntries([entry], into: context)

        viewModel.loadEntries()
        let found = viewModel.entry(for: today)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.feeling, 9)
    }

    func testEntryForDateReturnsNilWhenNoMatch() throws {
        let entry = makeEntry(daysAgo: 0)
        try insertEntries([entry], into: context)

        viewModel.loadEntries()
        let farPast = Calendar.current.date(byAdding: .year, value: -5, to: Date())!
        XCTAssertNil(viewModel.entry(for: farPast))
    }

    func testEntryForDateMatchesSameDayRegardlessOfTime() throws {
        let entry = makeEntry(daysAgo: 0, feeling: 7)
        try insertEntries([entry], into: context)

        viewModel.loadEntries()
        // Pass a mid-day date
        let noon = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let found = viewModel.entry(for: noon)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.feeling, 7)
    }
}
