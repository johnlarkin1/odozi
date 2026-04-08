import CloudKit
import CoreData
import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataContainer")

enum DataContainer {
    static let appGroupID = "group.com.johnlarkin.Odyssey"
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"

    private static let quotaDisabledKey = "cloudKitQuotaDisabled"
    private static let quotaDisabledDateKey = "cloudKitQuotaDisabledDate"
    private static let quotaRetryInterval: TimeInterval = 7 * 24 * 60 * 60 // 1 week

    /// User's explicit preference for iCloud sync
    static var isUserCloudKitEnabled: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
    }

    /// Whether CloudKit was auto-disabled due to quota exceeded (retries after cooldown)
    static var isQuotaDisabled: Bool {
        guard UserDefaults.standard.bool(forKey: quotaDisabledKey) else { return false }
        if let disabledDate = UserDefaults.standard.object(forKey: quotaDisabledDateKey) as? Date,
           Date().timeIntervalSince(disabledDate) > quotaRetryInterval
        {
            logger.info("CloudKit quota cooldown expired, re-enabling")
            UserDefaults.standard.set(false, forKey: quotaDisabledKey)
            return false
        }
        return true
    }

    static func disableCloudKitForQuota() {
        logger.warning("Disabling CloudKit sync due to quota exceeded — will retry in 1 week")
        UserDefaults.standard.set(true, forKey: quotaDisabledKey)
        UserDefaults.standard.set(Date(), forKey: quotaDisabledDateKey)
    }

    /// Observe CloudKit sync events and auto-disable on quota exceeded
    static func observeCloudKitErrors() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?["event"]
                as? NSPersistentCloudKitContainer.Event,
                let error = event.error as? NSError else { return }

            if error.code == CKError.quotaExceeded.rawValue {
                disableCloudKitForQuota()
                return
            }
            if error.code == CKError.partialFailure.rawValue {
                let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError] ?? [:]
                if partialErrors.values.contains(where: { $0.code == CKError.quotaExceeded.rawValue }) {
                    disableCloudKitForQuota()
                }
            }
        }
    }

    static func create(inMemory: Bool = false) throws -> ModelContainer {
        #if os(watchOS)
            let schema = Schema([DailyEntry.self, UserPreferences.self])
        #else
            let schema = Schema([DailyEntry.self, UserPreferences.self, Achievement.self])
        #endif

        if inMemory {
            let config = ModelConfiguration(
                "Odyssey",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        #if os(iOS)
            migrateStoreToAppGroupIfNeeded()
        #endif
        let storeURL = appGroupStoreURL
        let shouldUseCloudKit = isUserCloudKitEnabled && !isQuotaDisabled

        if shouldUseCloudKit {
            do {
                let cloudConfig = ModelConfiguration(
                    "Odyssey",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .private("iCloud.com.johnlarkin.Odyssey")
                )
                let container = try ModelContainer(for: schema, configurations: [cloudConfig])
                logger.info("CloudKit container opened successfully")
                observeCloudKitErrors()
                return container
            } catch {
                logger.error("CloudKit container failed: \(error)")
            }
        }

        // Local-only (explicit .none — default .automatic auto-enables CloudKit
        // when iCloud entitlements are present)
        let localConfig = ModelConfiguration(
            "Odyssey",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfig])
    }

    static var appGroupStoreURL: URL {
        #if os(macOS)
            // macOS: store in Application Support (no App Group needed)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let odysseyDir = appSupport.appendingPathComponent("Odyssey")
            try? FileManager.default.createDirectory(at: odysseyDir, withIntermediateDirectories: true)
            return odysseyDir.appendingPathComponent("Odyssey.store")
        #elseif os(watchOS)
            // watchOS: use App Group shared with iOS companion
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) {
                return container.appendingPathComponent("Odyssey.store")
            }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("Odyssey.store")
        #else
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) {
                return container.appendingPathComponent("Odyssey.store")
            }
            logger.warning("App Group container unavailable, falling back to Application Support")
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            return appSupport.appendingPathComponent("Odyssey.store")
        #endif
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
            let dest = URL(fileURLWithPath: appGroupURL.path + ext)
            if fileManager.fileExists(atPath: source.path) {
                do {
                    try fileManager.copyItem(at: source, to: dest)
                } catch {
                    logger.error("Failed to migrate store file \(source.lastPathComponent): \(error)")
                }
            }
        }
    }

    #if DEBUG && !EXTENSION
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
