import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataContainer")

struct DataContainer {
    static let appGroupID = "group.com.johnlarkin.Odyssey"

    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([DailyEntry.self])
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
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )!
        return container.appendingPathComponent("Odyssey.store")
    }

    static func migrateStoreToAppGroupIfNeeded() {
        let fileManager = FileManager.default
        let appGroupURL = appGroupStoreURL

        guard !fileManager.fileExists(atPath: appGroupURL.path) else { return }

        // Default Core Data store location
        let defaultURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Odyssey.sqlite")

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

    @MainActor
    static func previewContainer() throws -> ModelContainer {
        let container = try create(inMemory: true)
        let context = container.mainContext
        for entry in SampleData.entries {
            context.insert(entry)
        }
        try context.save()
        return container
    }
}
