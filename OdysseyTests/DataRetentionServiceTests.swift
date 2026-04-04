@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class DataRetentionServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        // Clear any leftover dismissal state
        UserDefaults.standard.removeObject(forKey: DataRetentionService.dismissedAtKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: DataRetentionService.dismissedAtKey)
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeOldEntry(yearsAgo: Int = 2) -> DailyEntry {
        let date = Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date())!
        return makeEntry(date: Calendar.current.startOfDay(for: date))
    }

    // MARK: - countOldEntries

    func testCountReturnsZeroForAccountUsers() throws {
        let old = makeOldEntry()
        try insertEntries([old], into: context)

        let count = DataRetentionService.countOldEntries(context: context, hasAccount: true)
        XCTAssertEqual(count, 0)
    }

    func testCountReturnsZeroWhenNoOldEntries() {
        let count = DataRetentionService.countOldEntries(context: context, hasAccount: false)
        XCTAssertEqual(count, 0)
    }

    func testCountReturnsCorrectCountForOldEntries() throws {
        let entries = [makeOldEntry(yearsAgo: 2), makeOldEntry(yearsAgo: 3), makeEntry(daysAgo: 1)]
        try insertEntries(entries, into: context)

        let count = DataRetentionService.countOldEntries(context: context, hasAccount: false)
        XCTAssertEqual(count, 2)
    }

    func testCountRespectsThirtyDayCooldown() throws {
        let old = makeOldEntry()
        try insertEntries([old], into: context)

        // Dismissed 10 days ago → within cooldown
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: DataRetentionService.dismissedAtKey)

        let count = DataRetentionService.countOldEntries(context: context, hasAccount: false)
        XCTAssertEqual(count, 0, "Should return 0 during 30-day cooldown")
    }

    func testCountAllowsAfterCooldownExpires() throws {
        let old = makeOldEntry()
        try insertEntries([old], into: context)

        // Dismissed 31 days ago → cooldown expired
        let thirtyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        UserDefaults.standard.set(thirtyOneDaysAgo, forKey: DataRetentionService.dismissedAtKey)

        let count = DataRetentionService.countOldEntries(context: context, hasAccount: false)
        XCTAssertEqual(count, 1, "Should count old entries after cooldown expires")
    }

    // MARK: - performCleanup

    func testPerformCleanupDeletesOldEntries() throws {
        let entries = [makeOldEntry(yearsAgo: 2), makeEntry(daysAgo: 1)]
        try insertEntries(entries, into: context)

        DataRetentionService.performCleanup(context: context)

        let remaining = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(remaining.count, 1)
    }

    func testPerformCleanupDoesNotDeleteRecentEntries() throws {
        let recent = [makeEntry(daysAgo: 0), makeEntry(daysAgo: 30), makeEntry(daysAgo: 200)]
        try insertEntries(recent, into: context)

        DataRetentionService.performCleanup(context: context)

        let remaining = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(remaining.count, 3)
    }

    // MARK: - recordDismissal

    func testRecordDismissalSetsDate() {
        DataRetentionService.recordDismissal()
        let stored = UserDefaults.standard.object(forKey: DataRetentionService.dismissedAtKey) as? Date
        XCTAssertNotNil(stored)
    }
}
