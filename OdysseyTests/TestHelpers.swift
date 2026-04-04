@testable import Odyssey
import SwiftData
import XCTest

// MARK: - Shared Test Data Helpers

/// Creates a `DailyEntry` with sensible defaults. All parameters are optional.
/// The entry is **not** inserted into any context — callers can use it unmanaged
/// (for pure-logic tests) or insert it explicitly.
func makeEntry(
    daysAgo: Int = 0,
    date: Date? = nil,
    feeling: Int = 5,
    singleWordFeeling: String = "",
    feelingColorHex: String = "#FFFFFF",
    sleepQuality: Int = 5,
    gratitude: String = "",
    win: String = "",
    tension: String = "",
    journalEntry: String = "",
    drinks: Int = 0,
    latitude: Double? = nil,
    longitude: Double? = nil,
    city: String? = nil,
    state: String? = nil,
    country: String? = nil,
    stepCount: Int? = nil,
    walkingDistanceMeters: Double? = nil,
    sleepHours: Double? = nil,
    sleepREMHours: Double? = nil,
    sleepDeepHours: Double? = nil,
    sleepCoreHours: Double? = nil,
    sleepAwakeMinutes: Double? = nil,
    sleepOnset: Date? = nil,
    sleepInterruptionCount: Int? = nil,
    sleepScore: Int? = nil,
    screenTimeSeconds: Double? = nil,
    pickups: Int? = nil
) -> DailyEntry {
    let entryDate = date ?? Calendar.current.startOfDay(for: Date().daysAgo(daysAgo))
    return DailyEntry(
        date: entryDate,
        feeling: feeling,
        singleWordFeeling: singleWordFeeling,
        feelingColorHex: feelingColorHex,
        sleepQuality: sleepQuality,
        gratitude: gratitude,
        win: win,
        tension: tension,
        journalEntry: journalEntry,
        drinks: drinks,
        latitude: latitude,
        longitude: longitude,
        city: city,
        state: state,
        country: country,
        stepCount: stepCount,
        walkingDistanceMeters: walkingDistanceMeters,
        sleepHours: sleepHours,
        sleepREMHours: sleepREMHours,
        sleepDeepHours: sleepDeepHours,
        sleepCoreHours: sleepCoreHours,
        sleepAwakeMinutes: sleepAwakeMinutes,
        sleepOnset: sleepOnset,
        sleepInterruptionCount: sleepInterruptionCount,
        sleepScore: sleepScore,
        screenTimeSeconds: screenTimeSeconds,
        pickups: pickups
    )
}

/// Inserts an array of entries into the given context and saves.
func insertEntries(_ entries: [DailyEntry], into context: ModelContext) throws {
    for entry in entries {
        context.insert(entry)
    }
    try context.save()
}
