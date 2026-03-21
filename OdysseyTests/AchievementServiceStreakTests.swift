@testable import Odyssey
import XCTest

@MainActor
extension AchievementServiceTests {
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

    func testStreakSevenUnlocksAtSevenDays() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entries = createConsecutiveEntries(count: 7)
        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("streak_7"))
        XCTAssertTrue(ids.contains("streak_3")) // Should also unlock lower tier
    }

    func testStreakUsesLongestNotCurrent() {
        // If a user had a 7-day streak in the past but current is 1,
        // they should still have streak_7 unlocked
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [DailyEntry] = []
        // 7-day streak ending 20 days ago
        for i in 0 ..< 7 {
            let date = calendar.date(byAdding: .day, value: -(20 + i), to: today)!
            let entry = DailyEntry(date: date)
            entry.journalEntry = "Old streak day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        // Single entry today (current streak = 1)
        let todayEntry = DailyEntry(date: today)
        todayEntry.journalEntry = "Today"
        todayEntry.hasUserSubmitted = true
        context.insert(todayEntry)
        entries.append(todayEntry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: todayEntry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("streak_7"))
    }

    // MARK: - DailyEntry+Streak Extensions

    func testLongestStreakWithGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [DailyEntry] = []
        // 5-day streak
        for i in 0 ..< 5 {
            let entry = DailyEntry(date: calendar.date(byAdding: .day, value: -i, to: today)!)
            entry.journalEntry = "Day \(i)"
            entries.append(entry)
        }
        // Gap, then 3-day streak
        for i in 7 ..< 10 {
            let entry = DailyEntry(date: calendar.date(byAdding: .day, value: -i, to: today)!)
            entry.journalEntry = "Day \(i)"
            entries.append(entry)
        }

        XCTAssertEqual(entries.longestStreak, 5)
    }

    func testLongestStreakWithNoEntries() {
        let entries: [DailyEntry] = []
        XCTAssertEqual(entries.longestStreak, 0)
    }

    func testLongestStreakWithSingleEntry() {
        let entry = DailyEntry()
        entry.journalEntry = "Solo"
        XCTAssertEqual([entry].longestStreak, 1)
    }

    func testLongestStreakIgnoresEntriesWithoutPromptData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [DailyEntry] = []
        for i in 0 ..< 5 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            if i == 2 {
                // This entry has no prompt data — should break streak
                entry.journalEntry = ""
            } else {
                entry.journalEntry = "Day \(i)"
            }
            entries.append(entry)
        }

        XCTAssertEqual(entries.longestStreak, 2)
    }

    func testLongestStreakWithDuplicateDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let entry1 = DailyEntry(date: today)
        entry1.journalEntry = "Morning"
        let entry2 = DailyEntry(date: today)
        entry2.journalEntry = "Evening"

        // Two entries on the same day should count as 1 day streak
        XCTAssertEqual([entry1, entry2].longestStreak, 1)
    }

    // MARK: - AchievementConditions

    func testConsecutiveDaysWithGapResetsStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [DailyEntry] = []
        // 3 consecutive days, then gap, then 3 more
        for i in [0, 1, 2, 5, 6, 7] {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            entries.append(entry)
        }

        // Should not reach 5 consecutive
        XCTAssertFalse(AchievementConditions.consecutiveDays(in: entries, count: 5) { $0.hasPromptData })
        // Should reach 3
        XCTAssertTrue(AchievementConditions.consecutiveDays(in: entries, count: 3) { $0.hasPromptData })
    }

    func testConsecutiveDaysWithEmptyEntries() {
        let entries: [DailyEntry] = []
        XCTAssertFalse(AchievementConditions.consecutiveDays(in: entries, count: 1) { _ in true })
    }

    func testHasComebackWithSingleEntry() {
        let entry = DailyEntry()
        entry.journalEntry = "Solo"
        entry.hasUserSubmitted = true

        XCTAssertFalse(AchievementConditions.hasComeback(entries: [entry], latest: entry))
    }
}
