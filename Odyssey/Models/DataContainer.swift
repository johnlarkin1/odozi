import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataContainer")

struct DataContainer {
    static let appGroupID = "group.com.johnlarkin.Odyssey"

    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([DailyEntry.self, UserPreferences.self, Achievement.self])
        let config: ModelConfiguration

        if inMemory {
            config = ModelConfiguration(
                "Odyssey",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            migrateStoreToAppGroupIfNeeded()
            let storeURL = appGroupStoreURL
            config = ModelConfiguration(
                "Odyssey",
                schema: schema,
                url: storeURL
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }

    static var appGroupStoreURL: URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return container.appendingPathComponent("Odyssey.store")
        }
        logger.warning("App Group container unavailable, falling back to Application Support")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Odyssey.store")
    }

    static func migrateStoreToAppGroupIfNeeded() {
        let fileManager = FileManager.default
        let appGroupURL = appGroupStoreURL

        guard !fileManager.fileExists(atPath: appGroupURL.path) else { return }

        // Default Core Data store location
        guard let appSupportURL = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first else { return }
        let defaultURL = appSupportURL.appendingPathComponent("Odyssey.sqlite")

        guard fileManager.fileExists(atPath: defaultURL.path) else { return }

        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let source = URL(fileURLWithPath: defaultURL.path + ext)
            let dest = URL(fileURLWithPath: appGroupURL.path.replacingOccurrences(of: ".store", with: ".sqlite") + ext)
            if fileManager.fileExists(atPath: source.path) {
                do {
                    try fileManager.copyItem(at: source, to: dest)
                } catch {
                    logger.error("Failed to migrate store file \(source.lastPathComponent): \(error)")
                }
            }
        }
    }

    #if DEBUG
    @MainActor
    static func previewContainer() throws -> ModelContainer {
        try createSeededContainer()
    }

    @MainActor
    static func createSeededContainer() throws -> ModelContainer {
        let container = try create(inMemory: true)
        let context = ModelContext(container)
        let entries = SampleData.entries
        for entry in entries {
            context.insert(entry)
        }
        try context.save()

        // Seed and evaluate achievements against sample data
        let achievementService = AchievementService(modelContext: context)
        achievementService.seedIfNeeded()
        let unlocked = achievementService.evaluateAll(entries: entries, latestEntry: entries.first)
        // Clear "new" indicator so the gallery looks settled
        for achievement in unlocked {
            achievement.isNew = false
        }
        try context.save()

        return container
    }
    #endif
}
