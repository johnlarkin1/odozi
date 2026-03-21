import Foundation
import os
import SwiftData

@MainActor
final class AchievementService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Achievements")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func seedIfNeeded() {
        let descriptor = FetchDescriptor<Achievement>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map(\.id))

        for definition in AchievementRegistry.all where !existingIDs.contains(definition.id) {
            let achievement = Achievement(
                id: definition.id,
                category: definition.category,
                title: definition.title,
                description: definition.description,
                iconName: definition.iconName,
                sortOrder: definition.sortOrder,
                tier: definition.tier
            )
            modelContext.insert(achievement)
        }
        try? modelContext.save()
    }

    func evaluateAll(entries: [DailyEntry], latestEntry: DailyEntry?) -> [Achievement] {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { $0.unlockedDate == nil }
        )
        let locked = (try? modelContext.fetch(descriptor)) ?? []
        let definitionMap = Dictionary(
            uniqueKeysWithValues: AchievementRegistry.all.map { ($0.id, $0) }
        )

        var newlyUnlocked: [Achievement] = []

        for achievement in locked {
            guard let definition = definitionMap[achievement.id] else { continue }
            if definition.condition(entries, latestEntry) {
                achievement.unlockedDate = Date()
                achievement.isNew = true
                newlyUnlocked.append(achievement)
                logger.info("Achievement unlocked: \(achievement.title)")
            }
        }

        if !newlyUnlocked.isEmpty {
            try? modelContext.save()
        }

        // Sort by tier descending so highest-tier is first
        return newlyUnlocked.sorted { $0.tier > $1.tier }
    }

    func markSeen(_ achievement: Achievement) {
        achievement.isNew = false
        try? modelContext.save()
    }

    func markAllSeen() {
        let predicate = #Predicate<Achievement> { $0.isNew == true }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        let unseen = (try? modelContext.fetch(descriptor)) ?? []
        for achievement in unseen {
            achievement.isNew = false
        }
        if !unseen.isEmpty {
            try? modelContext.save()
        }
    }

    func fetchAll() -> [String: [Achievement]] {
        let descriptor = FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(grouping: all, by: \.category)
    }

    func unlockedCount() -> Int {
        let predicate = #Predicate<Achievement> { $0.unlockedDate != nil }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func totalCount() -> Int {
        let descriptor = FetchDescriptor<Achievement>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func unseenCount() -> Int {
        let predicate = #Predicate<Achievement> { $0.isNew == true }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
