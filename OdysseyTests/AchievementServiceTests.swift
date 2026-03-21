@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class AchievementServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

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

    // MARK: - Helpers

    func createConsecutiveEntries(count: Int) -> [DailyEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries: [DailyEntry] = []

        for i in 0 ..< count {
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
