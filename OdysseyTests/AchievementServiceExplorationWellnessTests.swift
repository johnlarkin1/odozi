@testable import Odyssey
import XCTest

@MainActor
extension AchievementServiceTests {
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

    // MARK: - DailyEntry Location Extensions

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

    // MARK: - Wellness Achievements

    func testDryWeekUnlocksAtSevenConsecutiveDaysNoDrinks() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []
        for i in 0 ..< 7 {
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
        for i in 0 ..< 7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let entry = DailyEntry(date: date)
            entry.drinks = (i == 3) ? 2 : 0 // Drink on day 3 breaks streak
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

    func testStepChampionUnlocksAt10000Steps() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.stepCount = 10000
        entry.journalEntry = "Active day"
        entry.hasUserSubmitted = true
        context.insert(entry)
        try? context.save()

        let unlocked = service.evaluateAll(entries: [entry], latestEntry: entry)
        let ids = unlocked.map(\.id)
        XCTAssertTrue(ids.contains("step_master"))
    }

    func testStepChampionDoesNotUnlockAt9999Steps() {
        let service = AchievementService(modelContext: context)
        service.seedIfNeeded()

        let entry = DailyEntry()
        entry.stepCount = 9999
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
        for i in 0 ..< 30 {
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
        for i in 0 ..< 30 {
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

    // MARK: - DailyEntry Feeling Color Extensions

    func testUniqueFeelingColorCount() {
        let entry1 = DailyEntry()
        entry1.feelingColorHex = "#FF0000"

        let entry2 = DailyEntry()
        entry2.feelingColorHex = "#00FF00"

        let entry3 = DailyEntry()
        entry3.feelingColorHex = "#FFFFFF" // Default, should be excluded

        XCTAssertEqual([entry1, entry2, entry3].uniqueFeelingColorCount, 2)
    }

    func testUniqueGratitudeCount() {
        let entry1 = DailyEntry()
        entry1.gratitude = "sunshine"

        let entry2 = DailyEntry()
        entry2.gratitude = "sunshine" // Duplicate

        let entry3 = DailyEntry()
        entry3.gratitude = "family"

        let entry4 = DailyEntry()
        entry4.gratitude = "" // Empty, should be excluded

        XCTAssertEqual([entry1, entry2, entry3, entry4].uniqueGratitudeCount, 2)
    }
}
