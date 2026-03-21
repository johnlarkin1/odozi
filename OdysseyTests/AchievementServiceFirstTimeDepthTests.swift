@testable import Odyssey
import XCTest

@MainActor
extension AchievementServiceTests {
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

    func testGratefulHeartUnlocks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.gratitude = "Sunshine and fresh air"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("first_gratitude"))
    }

    func testGratefulHeartDoesNotUnlockWithEmptyGratitude() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.gratitude = ""
        entry.journalEntry = "Something"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("first_gratitude"))
    }

    func testFullWeekUnlocksAtSevenEntries() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        // 7 entries on non-consecutive days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []
        for i in [0, 2, 4, 6, 8, 10, 12] {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.journalEntry = "Entry \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.first)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("full_week"))
    }

    func testFullWeekDoesNotUnlockAtSixEntries() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []
        for i in 0 ..< 6 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.journalEntry = "Entry \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.first)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("full_week"))
    }

    func testMoodPioneerUnlocks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.feeling = 7
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("mood_pioneer"))
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

    func testDeepDiveDoesNotUnlockAt499Words() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = String(repeating: "word ", count: 499)
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("deep_dive"))
    }

    func testOpenBookUnlocksWithAllFieldsFilled() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.feeling = 7
        entry.singleWordFeeling = "happy"
        entry.gratitude = "family"
        entry.win = "finished project"
        entry.tension = "work deadline"
        entry.journalEntry = "Today was great"
        entry.sleepQuality = 8
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("open_book"))
    }

    func testOpenBookDoesNotUnlockWithMissingField() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.feeling = 7
        entry.singleWordFeeling = "happy"
        entry.gratitude = "family"
        entry.win = "" // Missing win
        entry.tension = "work deadline"
        entry.journalEntry = "Today was great"
        entry.sleepQuality = 8
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("open_book"))
    }

    func testThousandWordsUnlocks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        var entries: [DailyEntry] = []
        // 5 entries × 200 words each = 1000
        for i in 0 ..< 5 {
            let entry = DailyEntry()
            entry.journalEntry = String(repeating: "word ", count: 200)
            entry.hasUserSubmitted = true
            entry.singleWordFeeling = "day\(i)"
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("thousand_words"))
    }

    // MARK: - DailyEntry Word Count Extensions

    func testTotalJournalWordCount() {
        let entry1 = DailyEntry()
        entry1.journalEntry = "one two three"
        entry1.hasUserSubmitted = true

        let entry2 = DailyEntry()
        entry2.journalEntry = "four five"
        entry2.hasUserSubmitted = true

        XCTAssertEqual([entry1, entry2].totalJournalWordCount, 5)
    }

    func testTotalJournalWordCountExcludesNonPromptEntries() {
        let entry1 = DailyEntry()
        entry1.journalEntry = "one two three"
        entry1.hasUserSubmitted = true

        let entry2 = DailyEntry()
        entry2.journalEntry = ""
        // entry2 has no prompt data, shouldn't count

        XCTAssertEqual([entry1, entry2].totalJournalWordCount, 3)
    }

    func testTotalJournalWordCountEmptyEntries() {
        let entries: [DailyEntry] = []
        XCTAssertEqual(entries.totalJournalWordCount, 0)
    }
}
