// TODO: Replace with CloudKit sync
import Foundation
import os
import SwiftData

private let conflictLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SyncConflict")

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
              !entries.isEmpty
        else {
            pendingCount = 0
            return
        }

        pendingCount = entries.count
        status = .syncing

        // Process in batches
        for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, entries.count)
            let batch = Array(entries[batchStart ..< batchEnd])

            do {
                let uploadEntries = try await encryptBatch(batch)
                let payload = SyncUploadPayload(entries: uploadEntries)

                guard let token = await authManager?.getStoredToken() else {
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

        guard let token = await authManager.getStoredToken() else {
            status = .error("Not authenticated")
            return
        }

        do {
            var cursor: String?
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
        let sleepREMHours: Double?
        let sleepDeepHours: Double?
        let sleepCoreHours: Double?
        let sleepAwakeMinutes: Double?
        let sleepOnset: Date?
        let sleepInterruptionCount: Int?
        let sleepScore: Int?
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
                sleepREMHours: entry.sleepREMHours,
                sleepDeepHours: entry.sleepDeepHours,
                sleepCoreHours: entry.sleepCoreHours,
                sleepAwakeMinutes: entry.sleepAwakeMinutes,
                sleepOnset: entry.sleepOnset,
                sleepInterruptionCount: entry.sleepInterruptionCount,
                sleepScore: entry.sleepScore,
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

                    let encrypted = try SyncUploadEntry(
                        entryDate: snapshot.entryDate,
                        journalEntry: snapshot.journalEntry.isEmpty ? nil : await encryptionSvc.encrypt(snapshot.journalEntry),
                        gratitude: snapshot.gratitude.isEmpty ? nil : await encryptionSvc.encrypt(snapshot.gratitude),
                        win: snapshot.win.isEmpty ? nil : await encryptionSvc.encrypt(snapshot.win),
                        tension: snapshot.tension.isEmpty ? nil : await encryptionSvc.encrypt(snapshot.tension),
                        singleWordFeeling: snapshot.singleWordFeeling.isEmpty
                            ? nil : await encryptionSvc.encrypt(snapshot.singleWordFeeling),
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
                        sleepREMHours: snapshot.sleepREMHours,
                        sleepDeepHours: snapshot.sleepDeepHours,
                        sleepCoreHours: snapshot.sleepCoreHours,
                        sleepAwakeMinutes: snapshot.sleepAwakeMinutes,
                        sleepOnset: snapshot.sleepOnset.map { Self.iso8601.string(from: $0) },
                        sleepInterruptionCount: snapshot.sleepInterruptionCount,
                        sleepScore: snapshot.sleepScore,
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

    /// Holds decrypted values from a remote download entry for field-level comparison.
    private struct DecryptedRemoteEntry {
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
        let sleepREMHours: Double?
        let sleepDeepHours: Double?
        let sleepCoreHours: Double?
        let sleepAwakeMinutes: Double?
        let sleepOnset: Date?
        let sleepInterruptionCount: Int?
        let sleepScore: Int?
        let screenTimeSeconds: Double?
        let pickups: Int?
        let createdAt: Date?
        let updatedAt: Date?
    }

    /// Decrypts all encrypted fields of a download entry and returns a struct ready for comparison.
    private func decryptDownloadEntry(_ download: SyncDownloadEntry) async throws -> DecryptedRemoteEntry {
        let journalEntry: String
        if let encrypted = download.journalEntry {
            journalEntry = try await encryptionService.decrypt(encrypted)
        } else {
            journalEntry = ""
        }

        let gratitude: String
        if let encrypted = download.gratitude {
            gratitude = try await encryptionService.decrypt(encrypted)
        } else {
            gratitude = ""
        }

        let win: String
        if let encrypted = download.win {
            win = try await encryptionService.decrypt(encrypted)
        } else {
            win = ""
        }

        let tension: String
        if let encrypted = download.tension {
            tension = try await encryptionService.decrypt(encrypted)
        } else {
            tension = ""
        }

        let singleWordFeeling: String
        if let encrypted = download.singleWordFeeling {
            singleWordFeeling = try await encryptionService.decrypt(encrypted)
        } else {
            singleWordFeeling = ""
        }

        let latitude: Double?
        if let encrypted = download.latitude {
            latitude = try await encryptionService.decryptDouble(encrypted)
        } else {
            latitude = nil
        }

        let longitude: Double?
        if let encrypted = download.longitude {
            longitude = try await encryptionService.decryptDouble(encrypted)
        } else {
            longitude = nil
        }

        let city: String?
        if let encrypted = download.city {
            city = try await encryptionService.decrypt(encrypted)
        } else {
            city = nil
        }

        let state: String?
        if let encrypted = download.state {
            state = try await encryptionService.decrypt(encrypted)
        } else {
            state = nil
        }

        let country: String?
        if let encrypted = download.country {
            country = try await encryptionService.decrypt(encrypted)
        } else {
            country = nil
        }

        return DecryptedRemoteEntry(
            journalEntry: journalEntry,
            gratitude: gratitude,
            win: win,
            tension: tension,
            singleWordFeeling: singleWordFeeling,
            latitude: latitude,
            longitude: longitude,
            city: city,
            state: state,
            country: country,
            feeling: download.feeling,
            sleepQuality: download.sleepQuality,
            feelingColorHex: download.feelingColorHex,
            drinks: download.drinks,
            stepCount: download.stepCount,
            walkingDistanceMeters: download.walkingDistanceMeters,
            sleepHours: download.sleepHours,
            sleepREMHours: download.sleepREMHours,
            sleepDeepHours: download.sleepDeepHours,
            sleepCoreHours: download.sleepCoreHours,
            sleepAwakeMinutes: download.sleepAwakeMinutes,
            sleepOnset: download.sleepOnset.flatMap { Self.iso8601.date(from: $0) },
            sleepInterruptionCount: download.sleepInterruptionCount,
            sleepScore: download.sleepScore,
            screenTimeSeconds: download.screenTimeSeconds,
            pickups: download.pickups,
            createdAt: Self.iso8601.date(from: download.createdAt),
            updatedAt: Self.iso8601.date(from: download.updatedAt)
        )
    }

    /// Applies all remote fields to a local entry unconditionally (used for fresh creates).
    private func applyAllRemoteFields(_ remote: DecryptedRemoteEntry, to entry: DailyEntry) {
        entry.journalEntry = remote.journalEntry
        entry.gratitude = remote.gratitude
        entry.win = remote.win
        entry.tension = remote.tension
        entry.singleWordFeeling = remote.singleWordFeeling
        entry.latitude = remote.latitude
        entry.longitude = remote.longitude
        entry.city = remote.city
        entry.state = remote.state
        entry.country = remote.country
        entry.feeling = remote.feeling
        entry.sleepQuality = remote.sleepQuality
        entry.feelingColorHex = remote.feelingColorHex
        entry.drinks = remote.drinks
        entry.stepCount = remote.stepCount
        entry.walkingDistanceMeters = remote.walkingDistanceMeters
        entry.sleepHours = remote.sleepHours
        entry.sleepREMHours = remote.sleepREMHours
        entry.sleepDeepHours = remote.sleepDeepHours
        entry.sleepCoreHours = remote.sleepCoreHours
        entry.sleepAwakeMinutes = remote.sleepAwakeMinutes
        entry.sleepOnset = remote.sleepOnset
        entry.sleepInterruptionCount = remote.sleepInterruptionCount
        entry.sleepScore = remote.sleepScore
        entry.screenTimeSeconds = remote.screenTimeSeconds
        entry.pickups = remote.pickups

        if let createdAt = remote.createdAt {
            entry.createdAt = createdAt
        }
        if let updatedAt = remote.updatedAt {
            entry.updatedAt = updatedAt
        }
    }

    private func mergeEntry(_ download: SyncDownloadEntry, into context: ModelContext) async throws {
        guard let entryDate = Self.dateOnly.date(from: download.entryDate) else { return }

        let repository = DailyEntryRepository(context: context)
        let existingEntry = try? repository.fetchEntry(for: entryDate)

        let remoteTimestamp = Self.iso8601.date(from: download.updatedAt) ?? Date.distantPast

        if let existingEntry {
            // Both local and remote exist — field-level merge
            let localTimestamp = existingEntry.updatedAt

            // Fast path: if local is >5s newer and clearly dominant, skip merge
            if localTimestamp.timeIntervalSince(remoteTimestamp) > 5.0 {
                conflictLogger.debug("Fast path: local is >5s newer for \(download.entryDate), skipping merge")
                return
            }

            let remote = try await decryptDownloadEntry(download)
            mergeFields(local: existingEntry, remote: remote, localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp)

            existingEntry.updatedAt = max(localTimestamp, remoteTimestamp)
            existingEntry.needsSync = false
            existingEntry.lastSyncedAt = Date()
        } else {
            // No local entry — create and apply all remote fields
            let entry = try repository.fetchOrCreate(for: entryDate)
            let remote = try await decryptDownloadEntry(download)
            applyAllRemoteFields(remote, to: entry)
            entry.needsSync = false
            entry.lastSyncedAt = Date()
        }
    }

    // MARK: - Field-Level Merge

    /// Performs field-level merge of a decrypted remote entry into an existing local entry.
    private func mergeFields(
        local: DailyEntry,
        remote: DecryptedRemoteEntry,
        localTimestamp: Date,
        remoteTimestamp: Date
    ) {
        let entryDate = Self.dateOnly.string(from: local.date)

        // Text fields — prefer non-empty, then longer, then newer timestamp
        local.journalEntry = mergeTextField(
            local: local.journalEntry, remote: remote.journalEntry,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "journalEntry", entryDate: entryDate
        )
        local.gratitude = mergeTextField(
            local: local.gratitude, remote: remote.gratitude,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "gratitude", entryDate: entryDate
        )
        local.win = mergeTextField(
            local: local.win, remote: remote.win,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "win", entryDate: entryDate
        )
        local.tension = mergeTextField(
            local: local.tension, remote: remote.tension,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "tension", entryDate: entryDate
        )
        local.singleWordFeeling = mergeTextField(
            local: local.singleWordFeeling, remote: remote.singleWordFeeling,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "singleWordFeeling", entryDate: entryDate
        )
        local.feelingColorHex = mergeTextField(
            local: local.feelingColorHex, remote: remote.feelingColorHex,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "feelingColorHex", entryDate: entryDate
        )

        // Numeric fields — prefer non-zero, then newer timestamp
        local.feeling = mergeNumericField(
            local: local.feeling, remote: remote.feeling,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "feeling", entryDate: entryDate, defaultValue: 0
        )
        local.sleepQuality = mergeNumericField(
            local: local.sleepQuality, remote: remote.sleepQuality,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepQuality", entryDate: entryDate, defaultValue: 0
        )
        local.drinks = mergeNumericField(
            local: local.drinks, remote: remote.drinks,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "drinks", entryDate: entryDate, defaultValue: 0
        )

        // Location fields — merge as a group
        mergeLocationFields(
            localEntry: local, remote: remote,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            entryDate: entryDate
        )

        // Optional fields — prefer non-nil, then newer timestamp
        local.stepCount = mergeOptionalField(
            local: local.stepCount, remote: remote.stepCount,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "stepCount", entryDate: entryDate
        )
        local.walkingDistanceMeters = mergeOptionalField(
            local: local.walkingDistanceMeters, remote: remote.walkingDistanceMeters,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "walkingDistanceMeters", entryDate: entryDate
        )
        local.sleepHours = mergeOptionalField(
            local: local.sleepHours, remote: remote.sleepHours,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepHours", entryDate: entryDate
        )
        local.sleepREMHours = mergeOptionalField(
            local: local.sleepREMHours, remote: remote.sleepREMHours,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepREMHours", entryDate: entryDate
        )
        local.sleepDeepHours = mergeOptionalField(
            local: local.sleepDeepHours, remote: remote.sleepDeepHours,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepDeepHours", entryDate: entryDate
        )
        local.sleepCoreHours = mergeOptionalField(
            local: local.sleepCoreHours, remote: remote.sleepCoreHours,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepCoreHours", entryDate: entryDate
        )
        local.sleepAwakeMinutes = mergeOptionalField(
            local: local.sleepAwakeMinutes, remote: remote.sleepAwakeMinutes,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepAwakeMinutes", entryDate: entryDate
        )
        local.sleepOnset = mergeOptionalField(
            local: local.sleepOnset, remote: remote.sleepOnset,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepOnset", entryDate: entryDate
        )
        local.sleepInterruptionCount = mergeOptionalField(
            local: local.sleepInterruptionCount, remote: remote.sleepInterruptionCount,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepInterruptionCount", entryDate: entryDate
        )
        local.sleepScore = mergeOptionalField(
            local: local.sleepScore, remote: remote.sleepScore,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "sleepScore", entryDate: entryDate
        )
        local.screenTimeSeconds = mergeOptionalField(
            local: local.screenTimeSeconds, remote: remote.screenTimeSeconds,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "screenTimeSeconds", entryDate: entryDate
        )
        local.pickups = mergeOptionalField(
            local: local.pickups, remote: remote.pickups,
            localTimestamp: localTimestamp, remoteTimestamp: remoteTimestamp,
            fieldName: "pickups", entryDate: entryDate
        )
    }

    // MARK: - Merge Helpers

    /// Merges a text field: prefer non-empty over empty, then longer text, then newer timestamp.
    private func mergeTextField(
        local: String,
        remote: String,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String,
        entryDate: String
    ) -> String {
        // Both empty or identical — no conflict
        if local == remote { return local }

        let localEmpty = local.isEmpty
        let remoteEmpty = remote.isEmpty

        // Prefer non-empty over empty
        if localEmpty && !remoteEmpty {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (local empty)")
            return remote
        }
        if !localEmpty && remoteEmpty {
            conflictLogger.info("[\(entryDate)] \(fieldName): local wins (remote empty)")
            return local
        }

        // Both non-empty: prefer longer text (less data loss)
        if local.count != remote.count {
            if remote.count > local.count {
                conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (longer text: \(remote.count) vs \(local.count))")
                return remote
            } else {
                conflictLogger.info("[\(entryDate)] \(fieldName): local wins (longer text: \(local.count) vs \(remote.count))")
                return local
            }
        }

        // Equal length non-empty: timestamp breaks tie
        if remoteTimestamp > localTimestamp {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (newer timestamp, equal length)")
            return remote
        }
        conflictLogger.info("[\(entryDate)] \(fieldName): local wins (newer or equal timestamp, equal length)")
        return local
    }

    /// Merges a numeric field: prefer non-default over default, then newer timestamp.
    private func mergeNumericField(
        local: Int,
        remote: Int,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String,
        entryDate: String,
        defaultValue: Int
    ) -> Int {
        // Identical — no conflict
        if local == remote { return local }

        let localIsDefault = local == defaultValue
        let remoteIsDefault = remote == defaultValue

        // Prefer non-default over default
        if localIsDefault && !remoteIsDefault {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (local is default \(defaultValue))")
            return remote
        }
        if !localIsDefault && remoteIsDefault {
            conflictLogger.info("[\(entryDate)] \(fieldName): local wins (remote is default \(defaultValue))")
            return local
        }

        // Both non-default: timestamp breaks tie
        if remoteTimestamp > localTimestamp {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (newer timestamp, \(remote) vs \(local))")
            return remote
        }
        conflictLogger.info("[\(entryDate)] \(fieldName): local wins (newer or equal timestamp, \(local) vs \(remote))")
        return local
    }

    /// Merges an optional field: prefer non-nil over nil, then newer timestamp.
    private func mergeOptionalField<T: Equatable>(
        local: T?,
        remote: T?,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String,
        entryDate: String
    ) -> T? {
        // Both nil or identical — no conflict
        if local == remote { return local }

        // Prefer non-nil over nil
        if local == nil, remote != nil {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (local nil)")
            return remote
        }
        if local != nil, remote == nil {
            conflictLogger.info("[\(entryDate)] \(fieldName): local wins (remote nil)")
            return local
        }

        // Both non-nil but different: timestamp breaks tie
        if remoteTimestamp > localTimestamp {
            conflictLogger.info("[\(entryDate)] \(fieldName): remote wins (newer timestamp)")
            return remote
        }
        conflictLogger.info("[\(entryDate)] \(fieldName): local wins (newer or equal timestamp)")
        return local
    }

    /// Merges all 5 location fields as a group. If either side has a non-nil latitude
    /// (indicating location data exists), prefer that side's complete location set.
    /// Timestamp breaks ties when both have location data.
    private func mergeLocationFields(
        localEntry: DailyEntry,
        remote: DecryptedRemoteEntry,
        localTimestamp: Date,
        remoteTimestamp: Date,
        entryDate: String
    ) {
        let localHasLocation = localEntry.latitude != nil
        let remoteHasLocation = remote.latitude != nil

        // Both have no location or identical coordinates — no conflict
        if !localHasLocation, !remoteHasLocation { return }
        if localEntry.latitude == remote.latitude,
           localEntry.longitude == remote.longitude,
           localEntry.city == remote.city,
           localEntry.state == remote.state,
           localEntry.country == remote.country {
            return
        }

        // Prefer the side with location data
        if !localHasLocation, remoteHasLocation {
            conflictLogger.info("[\(entryDate)] location: remote wins (local has no location)")
            applyRemoteLocation(remote, to: localEntry)
            return
        }
        if localHasLocation, !remoteHasLocation {
            conflictLogger.info("[\(entryDate)] location: local wins (remote has no location)")
            return
        }

        // Both have location data: timestamp breaks tie
        if remoteTimestamp > localTimestamp {
            conflictLogger.info("[\(entryDate)] location: remote wins (newer timestamp)")
            applyRemoteLocation(remote, to: localEntry)
        } else {
            conflictLogger.info("[\(entryDate)] location: local wins (newer or equal timestamp)")
        }
    }

    /// Applies all 5 location fields from a decrypted remote entry to a local entry.
    private func applyRemoteLocation(_ remote: DecryptedRemoteEntry, to entry: DailyEntry) {
        entry.latitude = remote.latitude
        entry.longitude = remote.longitude
        entry.city = remote.city
        entry.state = remote.state
        entry.country = remote.country
    }
}
