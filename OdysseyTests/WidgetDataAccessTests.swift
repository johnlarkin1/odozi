@testable import Odyssey
import SwiftData
import XCTest

/// Tests for the widget data access logic (fetch today, record mood, streak calculation).
/// Uses the same in-memory SwiftData container pattern as DailyEntryViewModelTests.
/// These validate the core logic that WidgetDataAccess uses in the widget target.
@MainActor
final class WidgetDataAccessTests: XCTestCase {
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

    private func insertEntry(
        daysAgo: Int = 0,
        feeling: Int = 5,
        hasUserSubmitted: Bool = false
    ) throws -> DailyEntry {
        let date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let entry = DailyEntry(date: date, feeling: feeling)
        entry.hasUserSubmitted = hasUserSubmitted
        context.insert(entry)
        try context.save()
        return entry
    }

    // MARK: - Fetch Today Entry

    func testFetchTodayEntryReturnsNilWhenEmpty() {
        let entry = fetchTodayEntry()
        XCTAssertNil(entry)
    }

    func testFetchTodayEntryReturnsTodaysEntry() throws {
        let created = try insertEntry(daysAgo: 0, feeling: 8)
        let fetched = fetchTodayEntry()
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.feeling, created.feeling)
    }

    func testFetchTodayEntryIgnoresYesterday() throws {
        _ = try insertEntry(daysAgo: 1, feeling: 6)
        let fetched = fetchTodayEntry()
        XCTAssertNil(fetched)
    }

    // MARK: - Record Mood

    func testRecordMoodCreatesNewEntry() throws {
        try recordMood(7)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.feeling, 7)
        XCTAssertFalse(entries.first?.hasUserSubmitted ?? true, "Widget mood should not mark as user submitted")
    }

    func testRecordMoodUpdatesExistingEntry() throws {
        _ = try insertEntry(daysAgo: 0, feeling: 3)

        try recordMood(9)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1, "Should update existing, not create duplicate")
        XCTAssertEqual(entries.first?.feeling, 9)
    }

    func testRecordMoodPreservesHasUserSubmitted() throws {
        _ = try insertEntry(daysAgo: 0, feeling: 5, hasUserSubmitted: true)

        try recordMood(8)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertTrue(entries.first?.hasUserSubmitted ?? false, "Should preserve existing hasUserSubmitted flag")
        XCTAssertEqual(entries.first?.feeling, 8)
    }

    func testRecordMoodUpdatesTimestamp() throws {
        let original = try insertEntry(daysAgo: 0, feeling: 5)
        let originalUpdatedAt = original.updatedAt

        // Small delay so timestamps differ
        Thread.sleep(forTimeInterval: 0.05)

        try recordMood(8)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertGreaterThan(entries.first!.updatedAt, originalUpdatedAt)
    }

    func testRecordMoodDoesNotAffectYesterdaysEntry() throws {
        _ = try insertEntry(daysAgo: 1, feeling: 4)

        try recordMood(9)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 2, "Should create today's entry without touching yesterday's")

        let sorted = entries.sorted { $0.date > $1.date }
        XCTAssertEqual(sorted[0].feeling, 9) // today
        XCTAssertEqual(sorted[1].feeling, 4) // yesterday unchanged
    }

    // MARK: - Streak Calculation

    func testStreakZeroWithNoEntries() {
        let streak = calculateStreak()
        XCTAssertEqual(streak, 0)
    }

    func testStreakCountsConsecutiveSubmittedDays() throws {
        for i in 0 ..< 5 {
            _ = try insertEntry(daysAgo: i, feeling: 7, hasUserSubmitted: true)
        }

        let streak = calculateStreak()
        XCTAssertEqual(streak, 5)
    }

    func testStreakBreaksOnGap() throws {
        _ = try insertEntry(daysAgo: 0, feeling: 7, hasUserSubmitted: true)
        _ = try insertEntry(daysAgo: 1, feeling: 7, hasUserSubmitted: true)
        // gap at daysAgo: 2
        _ = try insertEntry(daysAgo: 3, feeling: 7, hasUserSubmitted: true)

        let streak = calculateStreak()
        XCTAssertEqual(streak, 2)
    }

    func testStreakIgnoresNonSubmittedEntries() throws {
        _ = try insertEntry(daysAgo: 0, feeling: 7, hasUserSubmitted: false)
        _ = try insertEntry(daysAgo: 1, feeling: 7, hasUserSubmitted: true)

        let streak = calculateStreak()
        // Today not submitted, so streak starts from yesterday
        XCTAssertEqual(streak, 1)
    }

    func testStreakStartsFromYesterdayIfTodayNotSubmitted() throws {
        // Today exists but not submitted; yesterday + day before submitted
        _ = try insertEntry(daysAgo: 0, feeling: 5, hasUserSubmitted: false)
        _ = try insertEntry(daysAgo: 1, feeling: 7, hasUserSubmitted: true)
        _ = try insertEntry(daysAgo: 2, feeling: 8, hasUserSubmitted: true)

        let streak = calculateStreak()
        XCTAssertEqual(streak, 2)
    }

    // MARK: - Private helpers (mirror WidgetDataAccess logic)

    /// Mirrors WidgetDataAccess.fetchTodayEntry — same predicate logic
    private func fetchTodayEntry() -> DailyEntry? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Mirrors WidgetDataAccess.recordMood — same fetch-or-create logic
    private func recordMood(_ value: Int) throws {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        descriptor.fetchLimit = 1

        let entry: DailyEntry
        if let existing = try context.fetch(descriptor).first {
            entry = existing
        } else {
            entry = DailyEntry(date: startOfDay)
            context.insert(entry)
        }

        entry.feeling = value
        entry.updatedAt = Date()
        try context.save()
    }

    /// Mirrors WidgetDataAccess.calculateStreak — same walk-backwards logic
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0 ..< 365 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            var descriptor = FetchDescriptor<DailyEntry>(
                predicate: #Predicate<DailyEntry> { entry in
                    entry.date >= checkDate && entry.date < nextDay && entry.hasUserSubmitted == true
                }
            )
            descriptor.fetchLimit = 1

            if let count = try? context.fetchCount(descriptor), count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if streak == 0 {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            } else {
                break
            }
        }

        return streak
    }
}
