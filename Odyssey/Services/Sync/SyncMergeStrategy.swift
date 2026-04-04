import Foundation
import os

private let conflictLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SyncConflict")

/// Extracted merge helpers for field-level sync conflict resolution.
/// These are pure functions (aside from logging) with no dependency on SyncService state.
enum SyncMergeStrategy {
    /// Merges a text field: prefer non-empty over empty, then longer text, then newer timestamp.
    static func mergeTextField(
        local: String,
        remote: String,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String = "",
        entryDate: String = ""
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
    static func mergeNumericField(
        local: Int,
        remote: Int,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String = "",
        entryDate: String = "",
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
    static func mergeOptionalField<T: Equatable>(
        local: T?,
        remote: T?,
        localTimestamp: Date,
        remoteTimestamp: Date,
        fieldName: String = "",
        entryDate: String = ""
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
    static func mergeLocationFields(
        localEntry: DailyEntry,
        remoteLatitude: Double?,
        remoteLongitude: Double?,
        remoteCity: String?,
        remoteState: String?,
        remoteCountry: String?,
        localTimestamp: Date,
        remoteTimestamp: Date,
        entryDate: String = ""
    ) {
        let localHasLocation = localEntry.latitude != nil
        let remoteHasLocation = remoteLatitude != nil

        // Both have no location or identical coordinates — no conflict
        if !localHasLocation, !remoteHasLocation { return }
        if localEntry.latitude == remoteLatitude,
           localEntry.longitude == remoteLongitude,
           localEntry.city == remoteCity,
           localEntry.state == remoteState,
           localEntry.country == remoteCountry {
            return
        }

        // Prefer the side with location data
        if !localHasLocation, remoteHasLocation {
            conflictLogger.info("[\(entryDate)] location: remote wins (local has no location)")
            applyLocation(latitude: remoteLatitude, longitude: remoteLongitude, city: remoteCity, state: remoteState, country: remoteCountry, to: localEntry)
            return
        }
        if localHasLocation, !remoteHasLocation {
            conflictLogger.info("[\(entryDate)] location: local wins (remote has no location)")
            return
        }

        // Both have location data: timestamp breaks tie
        if remoteTimestamp > localTimestamp {
            conflictLogger.info("[\(entryDate)] location: remote wins (newer timestamp)")
            applyLocation(latitude: remoteLatitude, longitude: remoteLongitude, city: remoteCity, state: remoteState, country: remoteCountry, to: localEntry)
        } else {
            conflictLogger.info("[\(entryDate)] location: local wins (newer or equal timestamp)")
        }
    }

    /// Applies location fields to an entry.
    static func applyLocation(
        latitude: Double?,
        longitude: Double?,
        city: String?,
        state: String?,
        country: String?,
        to entry: DailyEntry
    ) {
        entry.latitude = latitude
        entry.longitude = longitude
        entry.city = city
        entry.state = state
        entry.country = country
    }
}
