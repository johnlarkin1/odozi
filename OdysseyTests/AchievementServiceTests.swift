import XCTest
import SwiftData
@testable import Odyssey

@MainActor
final class AchievementServiceTests: XCTestCase {

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

    // MARK: - Seeding

    func testSeederIsIdempotent() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()
        let count1 = service.totalCount()
        XCTAssertGreaterThan(count1, 0)

        service.seedIfNeeded()
        let count2 = service.totalCount()
        XCTAssertEqual(count1, count2)
    }

    // MARK: - Streak Achievements

    func testStreakThreeUnlocksAtThreeDays() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entries = createConsecutiveEntries(count: 3)
        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("streak_3"))
    }

    func testStreakThreeDoesNotUnlockAtTwo() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entries = createConsecutiveEntries(count: 2)
        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("streak_3"))
    }

    // MARK: - First-Time Achievements

    func testFirstEntryUnlocks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Hello world"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("first_entry"))
    }

    // MARK: - Depth Achievements

    func testDeepDive500Words() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = String(repeating: "word ", count: 500)
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("deep_dive"))
    }

    // MARK: - Wellness Achievements

    func testComebackAfterSevenDayGap() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: today)!

        let oldEntry = DailyEntry(date: eightDaysAgo)
        oldEntry.journalEntry = "Old entry"
        oldEntry.hasUserSubmitted = true
        context.insert(oldEntry)

        let newEntry = DailyEntry(date: today)
        newEntry.journalEntry = "Back again"
        newEntry.hasUserSubmitted = true
        context.insert(newEntry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [oldEntry, newEntry], latestEntry: newEntry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("comeback"))
    }

    // MARK: - Already Unlocked Not Re-Evaluated

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
        // Previously unlocked achievements should not appear again
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

    // MARK: - DailyEntry+Streak Extensions

    func testLongestStreakWithGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [DailyEntry] = []
        // 5-day streak
        for i in 0..<5 {
            let entry = DailyEntry(date: calendar.date(byAdding: .day, value: -i, to: today)!)
            entry.journalEntry = "Day \(i)"
            entries.append(entry)
        }
        // Gap, then 3-day streak
        for i in 7..<10 {
            let entry = DailyEntry(date: calendar.date(byAdding: .day, value: -i, to: today)!)
            entry.journalEntry = "Day \(i)"
            entries.append(entry)
        }

        XCTAssertEqual(entries.longestStreak, 5)
    }

    func testTotalJournalWordCount() {
        let entry1 = DailyEntry()
        entry1.journalEntry = "one two three"
        entry1.hasUserSubmitted = true

        let entry2 = DailyEntry()
        entry2.journalEntry = "four five"
        entry2.hasUserSubmitted = true

        XCTAssertEqual([entry1, entry2].totalJournalWordCount, 5)
    }

    func testUniqueCityCount() {
        let entry1 = DailyEntry()
        entry1.city = "Chicago"

        let entry2 = DailyEntry()
        entry2.city = "Chicago"

        let entry3 = DailyEntry()
        entry3.city = "New York"

        XCTAssertEqual([entry1, entry2, entry3].uniqueCityCount, 2)
    }

    // MARK: - Helpers

    private func createConsecutiveEntries(count: Int) -> [DailyEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []

        for i in 0..<count {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()
        return entries
    }
}
