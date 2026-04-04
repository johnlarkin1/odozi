@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class JourneyExplorerViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: JourneyExplorerViewModel!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        viewModel = JourneyExplorerViewModel(modelContext: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        viewModel = nil
    }

    // MARK: - loadEntries

    func testLoadEntriesPopulates() throws {
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 1)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        XCTAssertEqual(viewModel.entries.count, 2)
    }

    // MARK: - filteredEntries

    func testFilteredEntriesAllTimeIncludesAll() throws {
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 100), makeEntry(daysAgo: 365)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.filteredEntries.count, 3)
    }

    func testFilteredEntriesWeekExcludesOldEntries() throws {
        let entries = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 3), makeEntry(daysAgo: 30)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .week
        XCTAssertEqual(viewModel.filteredEntries.count, 2)
    }

    func testFilteredEntriesSortedByDateAscending() throws {
        let entries = [makeEntry(daysAgo: 5), makeEntry(daysAgo: 0), makeEntry(daysAgo: 3)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        let dates = viewModel.filteredEntries.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - locatedEntries

    func testLocatedEntriesExcludesWithoutCoordinates() throws {
        let entries = [
            makeEntry(daysAgo: 0, latitude: 40.7, longitude: -74.0),
            makeEntry(daysAgo: 1), // no coordinates
        ]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.locatedEntries.count, 1)
    }

    func testLocatedEntriesIncludesWithCoordinates() throws {
        let entries = [
            makeEntry(daysAgo: 0, latitude: 40.7, longitude: -74.0),
            makeEntry(daysAgo: 1, latitude: 34.0, longitude: -118.2),
        ]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.locatedEntries.count, 2)
    }

    // MARK: - sliderRange

    func testSliderRangeWithMultipleEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, latitude: 40.7, longitude: -74.0),
            makeEntry(daysAgo: 1, latitude: 34.0, longitude: -118.2),
            makeEntry(daysAgo: 2, latitude: 41.8, longitude: -87.6),
        ]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.sliderRange, 0 ... 2)
    }

    func testSliderRangeSingleEntry() throws {
        let entries = [makeEntry(daysAgo: 0, latitude: 40.7, longitude: -74.0)]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.sliderRange, 0 ... 0)
    }

    func testSliderRangeEmpty() {
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.sliderRange, 0 ... 0)
    }

    // MARK: - entryCount

    func testEntryCountMatchesLocatedEntries() throws {
        let entries = [
            makeEntry(daysAgo: 0, latitude: 40.7, longitude: -74.0),
            makeEntry(daysAgo: 1), // no location
            makeEntry(daysAgo: 2, latitude: 34.0, longitude: -118.2),
        ]
        try insertEntries(entries, into: context)

        viewModel.loadEntries()
        viewModel.dateRange = .allTime
        XCTAssertEqual(viewModel.entryCount, 2)
        XCTAssertEqual(viewModel.entryCount, viewModel.locatedEntries.count)
    }
}
