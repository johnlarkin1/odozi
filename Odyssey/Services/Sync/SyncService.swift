import Foundation
import SwiftData

@MainActor
@Observable
final class SyncService {
    var status: SyncStatus = .idle
    var lastSyncDate: Date?
    var pendingCount: Int = 0

    private let apiClient = APIClient()
    private let encryptionService = EncryptionService()
    private let batchSize = 50

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Sync Up

    func syncPendingEntries(modelContext: ModelContext, authManager: AuthManager? = nil) async {
        let predicate = #Predicate<DailyEntry> { $0.needsSync == true }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let entries = try? modelContext.fetch(descriptor),
              !entries.isEmpty else {
            pendingCount = 0
            return
        }

        pendingCount = entries.count
        status = .syncing

        // Process in batches
        for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, entries.count)
            let batch = Array(entries[batchStart..<batchEnd])

            do {
                let uploadEntries = try await encryptBatch(batch)
                let payload = SyncUploadPayload(entries: uploadEntries)

                guard let token = await authManager?.refreshTokenIfNeeded() else {
                    status = .error("Not authenticated")
                    return
                }

                let response = try await apiClient.uploadEntries(payload, token: token)

                // Mark entries as synced
                let syncedAt = Self.iso8601.date(from: response.syncedAt) ?? Date()
                for entry in batch {
                    entry.needsSync = false
                    entry.lastSyncedAt = syncedAt
                }
                try? modelContext.save()
                pendingCount = max(0, pendingCount - batch.count)
            } catch {
                status = .error(error.localizedDescription)
                return
            }
        }

        lastSyncDate = Date()
        status = .synced
    }

    // MARK: - Restore

    func restoreFromCloud(modelContext: ModelContext, authManager: AuthManager) async {
        status = .syncing

        guard let token = await authManager.refreshTokenIfNeeded() else {
            status = .error("Not authenticated")
            return
        }

        do {
            var cursor: String? = nil
            repeat {
                let response = try await apiClient.fetchEntries(since: nil, cursor: cursor, token: token)
                for downloadEntry in response.entries {
                    try await mergeEntry(downloadEntry, into: modelContext)
                }
                cursor = response.cursor
            } while cursor != nil

            try? modelContext.save()
            lastSyncDate = Date()
            status = .synced
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Private: Encryption

    /// Sendable snapshot of the DailyEntry fields needed for encryption,
    /// so we can safely pass data into concurrent task group children.
    private struct EntrySnapshot: Sendable {
        let index: Int
        let entryDate: String
        let journalEntry: String
        let gratitude: String
        let win: String
        let tension: String
        let singleWordFeeling: String
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
        let feeling: Int
        let sleepQuality: Int
        let feelingColorHex: String
        let drinks: Int
        let stepCount: Int?
        let walkingDistanceMeters: Double?
        let sleepHours: Double?
        let screenTimeSeconds: Double?
        let pickups: Int?
        let createdAt: String
        let updatedAt: String
    }

    private func encryptBatch(_ entries: [DailyEntry]) async throws -> [SyncUploadEntry] {
        // Snapshot entry data on the main actor before entering the task group
        let snapshots: [EntrySnapshot] = entries.enumerated().map { index, entry in
            EntrySnapshot(
                index: index,
                entryDate: Self.dateOnly.string(from: entry.date),
                journalEntry: entry.journalEntry,
                gratitude: entry.gratitude,
                win: entry.win,
                tension: entry.tension,
                singleWordFeeling: entry.singleWordFeeling,
                latitude: entry.latitude,
                longitude: entry.longitude,
                city: entry.city,
                state: entry.state,
                country: entry.country,
                feeling: entry.feeling,
                sleepQuality: entry.sleepQuality,
                feelingColorHex: entry.feelingColorHex,
                drinks: entry.drinks,
                stepCount: entry.stepCount,
                walkingDistanceMeters: entry.walkingDistanceMeters,
                sleepHours: entry.sleepHours,
                screenTimeSeconds: entry.screenTimeSeconds,
                pickups: entry.pickups,
                createdAt: Self.iso8601.string(from: entry.createdAt),
                updatedAt: Self.iso8601.string(from: entry.updatedAt)
            )
        }

        let encryptionSvc = encryptionService

        return try await withThrowingTaskGroup(of: (Int, SyncUploadEntry).self) { group in
            for snapshot in snapshots {
                group.addTask {
                    let encryptedLat: String? = if let lat = snapshot.latitude {
                        try await encryptionSvc.encryptDouble(lat)
                    } else {
                        nil
                    }

                    let encryptedLon: String? = if let lon = snapshot.longitude {
                        try await encryptionSvc.encryptDouble(lon)
                    } else {
                        nil
                    }

                    let encryptedCity: String? = if let city = snapshot.city {
                        try await encryptionSvc.encrypt(city)
                    } else {
                        nil
                    }

                    let encryptedState: String? = if let state = snapshot.state {
                        try await encryptionSvc.encrypt(state)
                    } else {
                        nil
                    }

                    let encryptedCountry: String? = if let country = snapshot.country {
                        try await encryptionSvc.encrypt(country)
                    } else {
                        nil
                    }

                    let encrypted = SyncUploadEntry(
                        entryDate: snapshot.entryDate,
                        journalEntry: snapshot.journalEntry.isEmpty ? nil : try await encryptionSvc.encrypt(snapshot.journalEntry),
                        gratitude: snapshot.gratitude.isEmpty ? nil : try await encryptionSvc.encrypt(snapshot.gratitude),
                        win: snapshot.win.isEmpty ? nil : try await encryptionSvc.encrypt(snapshot.win),
                        tension: snapshot.tension.isEmpty ? nil : try await encryptionSvc.encrypt(snapshot.tension),
                        singleWordFeeling: snapshot.singleWordFeeling.isEmpty ? nil : try await encryptionSvc.encrypt(snapshot.singleWordFeeling),
                        latitude: encryptedLat,
                        longitude: encryptedLon,
                        city: encryptedCity,
                        state: encryptedState,
                        country: encryptedCountry,
                        feeling: snapshot.feeling,
                        sleepQuality: snapshot.sleepQuality,
                        feelingColorHex: snapshot.feelingColorHex,
                        drinks: snapshot.drinks,
                        stepCount: snapshot.stepCount,
                        walkingDistanceMeters: snapshot.walkingDistanceMeters,
                        sleepHours: snapshot.sleepHours,
                        screenTimeSeconds: snapshot.screenTimeSeconds,
                        pickups: snapshot.pickups,
                        createdAt: snapshot.createdAt,
                        updatedAt: snapshot.updatedAt
                    )

                    return (snapshot.index, encrypted)
                }
            }

            var results = [(Int, SyncUploadEntry)]()
            results.reserveCapacity(snapshots.count)

            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - Private: Merge

    private func mergeEntry(_ download: SyncDownloadEntry, into context: ModelContext) async throws {
        guard let entryDate = Self.dateOnly.date(from: download.entryDate) else { return }

        let repository = DailyEntryRepository(context: context)
        let existingEntry = try? repository.fetchEntry(for: entryDate)

        // Last-write-wins: skip if local is newer
        if let existingEntry,
           let downloadUpdated = Self.iso8601.date(from: download.updatedAt),
           existingEntry.updatedAt >= downloadUpdated {
            return
        }

        let entry = try repository.fetchOrCreate(for: entryDate)

        // Decrypt and apply sensitive fields
        if let encrypted = download.journalEntry {
            entry.journalEntry = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.gratitude {
            entry.gratitude = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.win {
            entry.win = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.tension {
            entry.tension = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.singleWordFeeling {
            entry.singleWordFeeling = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.latitude {
            entry.latitude = try await encryptionService.decryptDouble(encrypted)
        }
        if let encrypted = download.longitude {
            entry.longitude = try await encryptionService.decryptDouble(encrypted)
        }
        if let encrypted = download.city {
            entry.city = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.state {
            entry.state = try await encryptionService.decrypt(encrypted)
        }
        if let encrypted = download.country {
            entry.country = try await encryptionService.decrypt(encrypted)
        }

        // Apply plaintext fields
        entry.feeling = download.feeling
        entry.sleepQuality = download.sleepQuality
        entry.feelingColorHex = download.feelingColorHex
        entry.drinks = download.drinks
        entry.stepCount = download.stepCount
        entry.walkingDistanceMeters = download.walkingDistanceMeters
        entry.sleepHours = download.sleepHours
        entry.screenTimeSeconds = download.screenTimeSeconds
        entry.pickups = download.pickups

        if let createdAt = Self.iso8601.date(from: download.createdAt) {
            entry.createdAt = createdAt
        }
        if let updatedAt = Self.iso8601.date(from: download.updatedAt) {
            entry.updatedAt = updatedAt
        }

        entry.needsSync = false
        entry.lastSyncedAt = Date()
    }
}
