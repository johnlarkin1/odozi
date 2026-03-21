@testable import Odyssey
import XCTest

@MainActor
extension AchievementServiceTests {
    // MARK: - Evaluation Behavior

    func testAlreadyUnlockedNotReEvaluated() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Test"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked1 = service.evaluateAll(entries: [entry], latestEntry: entry)
        XCTAssertFalse(unlocked1.isEmpty)

        let unlocked2 = service.evaluateAll(entries: [entry], latestEntry: entry)
        let firstIds = Set(unlocked1.map(\.id))
        let secondIds = Set(unlocked2.map(\.id))
        XCTAssertTrue(firstIds.isDisjoint(with: secondIds))
    }

    func testEvaluateReturnsOnlyNewlyUnlocked() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Test"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        for achievement in unlocked {
            XCTAssertTrue(achievement.isUnlocked)
            XCTAssertTrue(achievement.isNew)
        }
    }

    func testEvaluateAllReturnsHighestTierFirst() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        // Create entries that unlock achievements of different tiers
        let entries = createConsecutiveEntries(count: 7)
        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)

        // Verify sorted by tier descending
        guard unlocked.count >= 2 else { return }
        for i in 0 ..< (unlocked.count - 1) {
            XCTAssertGreaterThanOrEqual(unlocked[i].tier, unlocked[i + 1].tier)
        }
    }

    func testEvaluateWithEmptyEntriesUnlocksNothing() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let unlocked = service.evaluateAll(entries: [], latestEntry: nil)
        XCTAssertTrue(unlocked.isEmpty)
    }

    // MARK: - Service Methods

    func testMarkSeen() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Test"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        XCTAssertGreaterThan(service.unseenCount(), 0)

        for achievement in unlocked {
            service.markSeen(achievement)
        }
        // All achievements from this evaluation should now be seen
        let stillUnseen = service.unseenCount()
        XCTAssertEqual(stillUnseen, 0)
    }

    func testMarkAllSeen() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Test"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        _ = service.evaluateAll(entries: [entry], latestEntry: entry)
        XCTAssertGreaterThan(service.unseenCount(), 0)

        service.markAllSeen()
        XCTAssertEqual(service.unseenCount(), 0)
    }

    func testFetchAllGroupsByCategory() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let grouped = service.fetchAll()
        XCTAssertNotNil(grouped["streak"])
        XCTAssertNotNil(grouped["first"])
        XCTAssertNotNil(grouped["depth"])
        XCTAssertNotNil(grouped["exploration"])
        XCTAssertNotNil(grouped["wellness"])

        // Total across all groups should equal registry count
        let total = grouped.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, AchievementRegistry.all.count)
    }

    func testUnlockedCountMatchesEvaluated() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()
        XCTAssertEqual(service.unlockedCount(), 0)

        let entry = DailyEntry()
        entry.journalEntry = "Test"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        XCTAssertEqual(service.unlockedCount(), unlocked.count)
    }
}
