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

    private func encryptBatch(_ entries: [DailyEntry]) async throws -> [SyncUploadEntry] {
        var uploadEntries: [SyncUploadEntry] = []

        for entry in entries {
            let encryptedLat: String? = if let lat = entry.latitude {
                try await encryptionService.encryptDouble(lat)
            } else {
                nil
            }

            let encryptedLon: String? = if let lon = entry.longitude {
                try await encryptionService.encryptDouble(lon)
            } else {
                nil
            }

            let encryptedCity: String? = if let city = entry.city {
                try await encryptionService.encrypt(city)
            } else {
                nil
            }

            let encryptedState: String? = if let state = entry.state {
                try await encryptionService.encrypt(state)
            } else {
                nil
            }

            let encryptedCountry: String? = if let country = entry.country {
                try await encryptionService.encrypt(country)
            } else {
                nil
            }

            let encrypted = SyncUploadEntry(
                entryDate: Self.dateOnly.string(from: entry.date),
                journalEntry: entry.journalEntry.isEmpty ? nil : try await encryptionService.encrypt(entry.journalEntry),
                gratitude: entry.gratitude.isEmpty ? nil : try await encryptionService.encrypt(entry.gratitude),
                win: entry.win.isEmpty ? nil : try await encryptionService.encrypt(entry.win),
                tension: entry.tension.isEmpty ? nil : try await encryptionService.encrypt(entry.tension),
                singleWordFeeling: entry.singleWordFeeling.isEmpty ? nil : try await encryptionService.encrypt(entry.singleWordFeeling),
                latitude: encryptedLat,
                longitude: encryptedLon,
                city: encryptedCity,
                state: encryptedState,
                country: encryptedCountry,
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
            uploadEntries.append(encrypted)
        }

        return uploadEntries
    }

    // MARK: - Private: Merge

    private func mergeEntry(_ download: SyncDownloadEntry, into context: ModelContext) async throws {
        guard let entryDate = Self.dateOnly.date(from: download.entryDate) else { return }

        let predicate = #Predicate<DailyEntry> { $0.date == entryDate }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        let existing = try? context.fetch(descriptor).first

        // Last-write-wins: skip if local is newer
        if let existing,
           let downloadUpdated = Self.iso8601.date(from: download.updatedAt),
           existing.updatedAt >= downloadUpdated {
            return
        }

        let entry = existing ?? DailyEntry(date: entryDate)
        if existing == nil {
            context.insert(entry)
        }

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
