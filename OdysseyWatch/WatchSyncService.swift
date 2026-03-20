import Foundation
import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchSync")

@MainActor
@Observable
final class WatchSyncService {
    var status: SyncStatus = .idle

    private let apiClient = APIClient()
    private let encryption = EncryptionService()

    func syncPendingEntries(modelContext: ModelContext, authManager: WatchAuthManager) async {
        guard let token = authManager.sessionToken else {
            status = .idle
            return
        }

        status = .syncing

        do {
            // Upload pending entries
            let predicate = #Predicate<DailyEntry> { $0.needsSync == true }
            let descriptor = FetchDescriptor(predicate: predicate)
            let pending = try modelContext.fetch(descriptor)

            if !pending.isEmpty {
                let uploadEntries = try await buildUploadEntries(pending)
                let payload = SyncUploadPayload(entries: uploadEntries)
                let response = try await apiClient.uploadEntries(payload, token: token)
                logger.info("Uploaded \(response.count) entries from watch")

                for entry in pending {
                    entry.needsSync = false
                    entry.lastSyncedAt = Date()
                }
                try modelContext.save()
            }

            // Download new entries
            let lastSync = pending.compactMap(\.lastSyncedAt).max()
            let downloadResponse = try await apiClient.fetchEntries(since: lastSync, token: token)

            for remote in downloadResponse.entries {
                try await applyRemoteEntry(remote, modelContext: modelContext)
            }

            try modelContext.save()
            status = .synced
        } catch {
            logger.error("Watch sync failed: \(error)")
            status = .error(error.localizedDescription)
        }
    }

    private func buildUploadEntries(_ entries: [DailyEntry]) async throws -> [SyncUploadEntry] {
        var result: [SyncUploadEntry] = []
        let formatter = ISO8601DateFormatter()

        for entry in entries {
            let upload = SyncUploadEntry(
                entryDate: formatter.string(from: entry.date),
                journalEntry: entry.journalEntry.isEmpty ? nil : try await encryption.encrypt(entry.journalEntry),
                gratitude: entry.gratitude.isEmpty ? nil : try await encryption.encrypt(entry.gratitude),
                win: entry.win.isEmpty ? nil : try await encryption.encrypt(entry.win),
                tension: entry.tension.isEmpty ? nil : try await encryption.encrypt(entry.tension),
                singleWordFeeling: entry.singleWordFeeling.isEmpty ? nil : try await encryption.encrypt(entry.singleWordFeeling),
                latitude: entry.latitude.map { try await encryption.encryptDouble($0) },
                longitude: entry.longitude.map { try await encryption.encryptDouble($0) },
                city: entry.city.map { try await encryption.encrypt($0) },
                state: entry.state.map { try await encryption.encrypt($0) },
                country: entry.country.map { try await encryption.encrypt($0) },
                feeling: entry.feeling,
                sleepQuality: entry.sleepQuality,
                feelingColorHex: entry.feelingColorHex,
                drinks: entry.drinks,
                stepCount: entry.stepCount,
                walkingDistanceMeters: entry.walkingDistanceMeters,
                sleepHours: entry.sleepHours,
                screenTimeSeconds: entry.screenTimeSeconds,
                pickups: entry.pickups,
                createdAt: formatter.string(from: entry.createdAt),
                updatedAt: formatter.string(from: entry.updatedAt)
            )
            result.append(upload)
        }
        return result
    }

    private func applyRemoteEntry(_ remote: SyncDownloadEntry, modelContext: ModelContext) async throws {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: remote.entryDate) else { return }

        let repo = DailyEntryRepository(context: modelContext)
        let entry = try repo.fetchOrCreate(for: date)

        // Field-level merge: prefer non-empty values
        if let journal = remote.journalEntry, entry.journalEntry.isEmpty {
            entry.journalEntry = try await encryption.decrypt(journal)
        }
        if let gratitude = remote.gratitude, entry.gratitude.isEmpty {
            entry.gratitude = try await encryption.decrypt(gratitude)
        }
        if let win = remote.win, entry.win.isEmpty {
            entry.win = try await encryption.decrypt(win)
        }
        if let tension = remote.tension, entry.tension.isEmpty {
            entry.tension = try await encryption.decrypt(tension)
        }
        if let feeling = remote.singleWordFeeling, entry.singleWordFeeling.isEmpty {
            entry.singleWordFeeling = try await encryption.decrypt(feeling)
        }

        // Prefer remote metric values if local is nil/zero
        if entry.feeling == 5 && remote.feeling != 5 {
            entry.feeling = remote.feeling
        }
        if entry.stepCount == nil {
            entry.stepCount = remote.stepCount
        }
        if entry.sleepHours == nil {
            entry.sleepHours = remote.sleepHours
        }

        entry.lastSyncedAt = Date()
        entry.needsSync = false
    }
}
