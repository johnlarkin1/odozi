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

    // MARK: - Achievement Model

    func testIsUnlockedWhenDateIsSet() {
        let achievement = Achievement(id: "test", category: "test", title: "T", description: "D", iconName: "star")
        XCTAssertFalse(achievement.isUnlocked)
        achievement.unlockedDate = Date()
        XCTAssertTrue(achievement.isUnlocked)
    }

    func testIsUnlockedWhenDateIsNil() {
        let achievement = Achievement(id: "test", category: "test", title: "T", description: "D", iconName: "star")
        achievement.unlockedDate = nil
        XCTAssertFalse(achievement.isUnlocked)
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

    func testSeederCreatesAllRegistryEntries() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()
        XCTAssertEqual(service.totalCount(), AchievementRegistry.all.count)
    }

    func testSeededAchievementsAreAllLocked() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()
        XCTAssertEqual(service.unlockedCount(), 0)
    }

    func testSeederAddsNewDefinitionsOnUpdate() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()
        let countBefore = service.totalCount()

        // Manually insert a record that would conflict — seed should skip it
        let extra = Achievement(id: "custom_test", category: "test", title: "X", description: "X", iconName: "star")
        context.insert(extra)
        try? context.save()

        service.seedIfNeeded()
        // Should still have all registry entries + the manual one
        XCTAssertEqual(service.totalCount(), countBefore + 1)
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
        for i in 0..<7 {
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
        for i in 0..<6 {
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
        entry.win = ""  // Missing win
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
        for i in 0..<5 {
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

    // MARK: - Exploration Achievements

    func testPromptSamplerUnlocks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        // Need entries that collectively cover all prompt types
        let entry = DailyEntry()
        entry.feeling = 5
        entry.singleWordFeeling = "calm"
        entry.gratitude = "nature"
        entry.win = "ran a mile"
        entry.tension = "deadline"
        entry.journalEntry = "Reflections"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("prompt_sampler"))
    }

    func testPromptSamplerDoesNotUnlockWithMissingPromptType() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.feeling = 5
        entry.singleWordFeeling = "calm"
        entry.gratitude = "nature"
        // No win, no tension, no journal
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("prompt_sampler"))
    }

    func testJourneyMapperUnlocksAtFiveCities() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let cities = ["Chicago", "New York", "London", "Tokyo", "Paris"]
        var entries: [DailyEntry] = []
        for city in cities {
            let entry = DailyEntry()
            entry.city = city
            entry.journalEntry = "In \(city)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("journey_mapper"))
    }

    func testJourneyMapperDoesNotUnlockAtFourCities() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let cities = ["Chicago", "New York", "London", "Tokyo"]
        var entries: [DailyEntry] = []
        for city in cities {
            let entry = DailyEntry()
            entry.city = city
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("journey_mapper"))
    }

    func testGlobetrotterUnlocksAtThreeCountries() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let countries = ["US", "UK", "Japan"]
        var entries: [DailyEntry] = []
        for country in countries {
            let entry = DailyEntry()
            entry.country = country
            entry.journalEntry = "In \(country)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("globetrotter"))
    }

    // MARK: - Wellness Achievements

    func testDryWeekUnlocksAtSevenConsecutiveDaysNoDrinks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.drinks = 0
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.first)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("dry_week"))
    }

    func testDryWeekDoesNotUnlockWhenDrinkBreaksStreak() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.drinks = (i == 3) ? 2 : 0  // Drink on day 3 breaks streak
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.first)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("dry_week"))
    }

    func testStepMasterUnlocksAt10000Steps() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.stepCount = 10_000
        entry.journalEntry = "Active day"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("step_master"))
    }

    func testStepMasterDoesNotUnlockAt9999Steps() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.stepCount = 9_999
        entry.journalEntry = "Almost"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("step_master"))
    }

    func testColorSpectrumUnlocksAtTenColors() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let colors = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF",
                      "#00FFFF", "#FFA500", "#800080", "#008000", "#FFC0CB"]
        var entries: [DailyEntry] = []
        for hex in colors {
            let entry = DailyEntry()
            entry.feelingColorHex = hex
            entry.journalEntry = "Color"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("color_spectrum"))
    }

    func testColorSpectrumDoesNotCountDefaultWhite() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        // 9 unique colors + white default = should NOT unlock (white excluded)
        let colors = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF",
                      "#00FFFF", "#FFA500", "#800080", "#008000"]
        var entries: [DailyEntry] = []
        for hex in colors {
            let entry = DailyEntry()
            entry.feelingColorHex = hex
            entry.journalEntry = "Color"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        // Add entry with default white — should not count
        let whiteEntry = DailyEntry()
        whiteEntry.feelingColorHex = "#FFFFFF"
        whiteEntry.journalEntry = "White"
        whiteEntry.hasUserSubmitted = true
        context.insert(whiteEntry)
        entries.append(whiteEntry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("color_spectrum"))
    }

    func testGratitudeGardenUnlocksAt30UniqueEntries() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        var entries: [DailyEntry] = []
        for i in 0..<30 {
            let entry = DailyEntry()
            entry.gratitude = "Grateful for thing \(i)"
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("gratitude_garden"))
    }

    func testGratitudeGardenDuplicatesDoNotCount() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        var entries: [DailyEntry] = []
        // 30 entries but only 5 unique gratitude texts
        for i in 0..<30 {
            let entry = DailyEntry()
            entry.gratitude = "Same thing \(i % 5)"
            entry.journalEntry = "Day \(i)"
            entry.hasUserSubmitted = true
            context.insert(entry)
            entries.append(entry)
        }
        try? context.save()

        let unlocked = service.evaluateAll(entries: entries, latestEntry: entries.last)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("gratitude_garden"))
    }

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

    func testComebackDoesNotUnlockAtSixDayGap() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!

        let oldEntry = DailyEntry(date: sixDaysAgo)
        oldEntry.journalEntry = "Recent entry"
        oldEntry.hasUserSubmitted = true
        context.insert(oldEntry)

        let newEntry = DailyEntry(date: today)
        newEntry.journalEntry = "Today"
        newEntry.hasUserSubmitted = true
        context.insert(newEntry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [oldEntry, newEntry], latestEntry: newEntry)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("comeback"))
    }

    func testComebackRequiresLatestEntry() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.journalEntry = "Solo"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        // nil latestEntry should not trigger comeback
        let unlocked = service.evaluateAll(entries: [entry], latestEntry: nil)
        let ids = unlocked.map(\.id)
        XCTAssertFalse(ids.contains("comeback"))
    }

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
        for i in 0..<(unlocked.count - 1) {
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
        for i in 0..<5 {
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

    func testUniqueCityCount() {
        let entry1 = DailyEntry()
        entry1.city = "Chicago"

        let entry2 = DailyEntry()
        entry2.city = "Chicago"

        let entry3 = DailyEntry()
        entry3.city = "New York"

        XCTAssertEqual([entry1, entry2, entry3].uniqueCityCount, 2)
    }

    func testUniqueCityCountExcludesNil() {
        let entry1 = DailyEntry()
        entry1.city = "Chicago"

        let entry2 = DailyEntry()
        entry2.city = nil

        XCTAssertEqual([entry1, entry2].uniqueCityCount, 1)
    }

    func testUniqueCountryCount() {
        let entry1 = DailyEntry()
        entry1.country = "US"

        let entry2 = DailyEntry()
        entry2.country = "UK"

        let entry3 = DailyEntry()
        entry3.country = "US"

        XCTAssertEqual([entry1, entry2, entry3].uniqueCountryCount, 2)
    }

    func testUniqueFeelingColorCount() {
        let entry1 = DailyEntry()
        entry1.feelingColorHex = "#FF0000"

        let entry2 = DailyEntry()
        entry2.feelingColorHex = "#00FF00"

        let entry3 = DailyEntry()
        entry3.feelingColorHex = "#FFFFFF"  // Default, should be excluded

        XCTAssertEqual([entry1, entry2, entry3].uniqueFeelingColorCount, 2)
    }

    func testUniqueGratitudeCount() {
        let entry1 = DailyEntry()
        entry1.gratitude = "sunshine"

        let entry2 = DailyEntry()
        entry2.gratitude = "sunshine"  // Duplicate

        let entry3 = DailyEntry()
        entry3.gratitude = "family"

        let entry4 = DailyEntry()
        entry4.gratitude = ""  // Empty, should be excluded

        XCTAssertEqual([entry1, entry2, entry3, entry4].uniqueGratitudeCount, 2)
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
