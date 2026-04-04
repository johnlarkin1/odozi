@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class YearInReviewViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: YearInReviewViewModel!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        viewModel = YearInReviewViewModel(modelContext: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        viewModel = nil
    }

    func testDefaultYearIsCurrentYear() {
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertEqual(viewModel.selectedYear, currentYear)
    }

    func testProgressAtFirstCard() {
        viewModel.currentCardIndex = 0
        XCTAssertEqual(viewModel.progress, 0.0, accuracy: 0.001)
    }

    func testProgressAtLastCard() {
        viewModel.currentCardIndex = viewModel.totalCards - 1
        XCTAssertEqual(viewModel.progress, 1.0, accuracy: 0.001)
    }

    func testProgressAtMiddle() {
        viewModel.currentCardIndex = 5
        let expected = 5.0 / Double(viewModel.totalCards - 1)
        XCTAssertEqual(viewModel.progress, expected, accuracy: 0.001)
    }

    func testLoadDataPopulatesData() throws {
        // Insert entries for the current year so the service has data to work with
        let entries = (0 ..< 10).map { makeEntry(daysAgo: $0, feeling: $0 + 1, journalEntry: "Day \($0)") }
        try insertEntries(entries, into: context)

        viewModel.loadData()
        XCTAssertNotNil(viewModel.data)
    }
}
