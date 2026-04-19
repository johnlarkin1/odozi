import Foundation
import os
import SwiftData

private let repoLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DailyEntryRepository")

@MainActor
struct DailyEntryRepository {
    let context: ModelContext

    func fetchOrCreateToday() throws -> DailyEntry {
        try fetchOrCreate(for: Date())
    }

    /// Find-or-create the entry whose stored date falls on the same local
    /// calendar day as `date`. Matches entries regardless of which timezone
    /// they were originally authored in — so a NY-midnight row and an Austin
    /// query for the same calendar day resolve to the same entry.
    func fetchOrCreate(for date: Date) throws -> DailyEntry {
        if let existing = try fetchEntry(for: date) {
            return existing
        }
        let entry = DailyEntry(date: Calendar.current.startOfDay(for: date))
        context.insert(entry)
        return entry
    }

    func fetchEntry(for date: Date) throws -> DailyEntry? {
        let matches = try fetchEntries(onSameDayAs: date)
        return Self.pickPrimary(matches)
    }

    /// Returns every entry whose stored date shares a calendar day with
    /// `date`. More than one result means a duplicate created across a
    /// timezone change — callers should either dedupe or prefer the primary.
    func fetchEntries(onSameDayAs date: Date) throws -> [DailyEntry] {
        // Widen by +/- 36h to cover the full range of timezone offsets
        // (max real-world offset is 14h, so 36h is a comfortable margin).
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let windowStart = cal.date(byAdding: .hour, value: -36, to: dayStart) ?? dayStart
        let windowEnd = cal.date(byAdding: .hour, value: 60, to: dayStart) ?? dayStart

        let predicate = #Predicate<DailyEntry> {
            $0.date >= windowStart && $0.date < windowEnd
        }
        let candidates = try context.fetch(FetchDescriptor(predicate: predicate))
        return candidates.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    /// Merge multi-row calendar days into a single row. Runs once on app
    /// launch; safe to re-run. See notes at `mergeDuplicates(into:from:)`.
    @discardableResult
    func dedupeByCalendarDay() throws -> Int {
        let all = try context.fetch(FetchDescriptor<DailyEntry>())
        guard all.count > 1 else { return 0 }

        let cal = Calendar.current
        var buckets: [String: [DailyEntry]] = [:]
        let bucketKey: (Date) -> String = { date in
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        }
        for entry in all {
            buckets[bucketKey(entry.date), default: []].append(entry)
        }

        var merged = 0
        for (_, group) in buckets where group.count > 1 {
            let primary = Self.pickPrimary(group) ?? group[0]
            for other in group where other !== primary {
                mergeDuplicates(into: primary, from: other)
                context.delete(other)
                merged += 1
            }
            // Normalize the survivor's date to local startOfDay so future
            // equality checks stay stable within this timezone.
            primary.date = cal.startOfDay(for: primary.date)
            primary.updatedAt = Date()
        }

        if merged > 0 {
            try context.save()
            repoLogger.info("Deduped \(merged) cross-timezone DailyEntry duplicates")
        }
        return merged
    }

    // MARK: - Private helpers

    /// Prefer the row most likely to represent the "real" entry for the day:
    /// user-submitted > most prompt content > earliest createdAt.
    static func pickPrimary(_ entries: [DailyEntry]) -> DailyEntry? {
        guard !entries.isEmpty else { return nil }
        if entries.count == 1 { return entries[0] }

        return entries.max { a, b in
            if a.hasUserSubmitted != b.hasUserSubmitted {
                return !a.hasUserSubmitted && b.hasUserSubmitted
            }
            let aScore = contentScore(a)
            let bScore = contentScore(b)
            if aScore != bScore { return aScore < bScore }
            return a.createdAt > b.createdAt // earlier createdAt wins
        }
    }

    private static func contentScore(_ e: DailyEntry) -> Int {
        var s = 0
        if e.feeling > 0 { s += 1 }
        if e.sleepQuality > 0 { s += 1 }
        if !e.singleWordFeeling.isEmpty { s += 1 }
        if !e.gratitude.isEmpty { s += 1 }
        if !e.win.isEmpty { s += 1 }
        if !e.tension.isEmpty { s += 1 }
        if !e.journalEntry.isEmpty { s += 1 }
        if e.latitude != nil { s += 1 }
        if e.stepCount != nil { s += 1 }
        if e.sleepHours != nil { s += 1 }
        if e.screenTimeSeconds != nil { s += 1 }
        if let photos = e.attachedPhotoData, !photos.isEmpty { s += 1 }
        return s
    }

    /// Copy non-empty/non-nil fields from `src` into `dst` without clobbering
    /// values `dst` already has. Photos and workout arrays are unioned.
    private func mergeDuplicates(into dst: DailyEntry, from src: DailyEntry) {
        if dst.feeling == 0 { dst.feeling = src.feeling }
        if dst.sleepQuality == 0 { dst.sleepQuality = src.sleepQuality }
        if dst.drinks == 0 { dst.drinks = src.drinks }
        if dst.singleWordFeeling.isEmpty { dst.singleWordFeeling = src.singleWordFeeling }
        if dst.feelingColorHex.caseInsensitiveCompare("#FFFFFF") == .orderedSame {
            dst.feelingColorHex = src.feelingColorHex
        }
        if dst.gratitude.isEmpty { dst.gratitude = src.gratitude }
        if dst.win.isEmpty { dst.win = src.win }
        if dst.tension.isEmpty { dst.tension = src.tension }
        if dst.journalEntry.isEmpty { dst.journalEntry = src.journalEntry }

        if dst.latitude == nil { dst.latitude = src.latitude }
        if dst.longitude == nil { dst.longitude = src.longitude }
        if dst.city == nil { dst.city = src.city }
        if dst.state == nil { dst.state = src.state }
        if dst.country == nil { dst.country = src.country }
        if dst.locationCapturedAt == nil { dst.locationCapturedAt = src.locationCapturedAt }

        if dst.stepCount == nil { dst.stepCount = src.stepCount }
        if dst.walkingDistanceMeters == nil { dst.walkingDistanceMeters = src.walkingDistanceMeters }
        if dst.sleepHours == nil { dst.sleepHours = src.sleepHours }
        if dst.sleepREMHours == nil { dst.sleepREMHours = src.sleepREMHours }
        if dst.sleepDeepHours == nil { dst.sleepDeepHours = src.sleepDeepHours }
        if dst.sleepCoreHours == nil { dst.sleepCoreHours = src.sleepCoreHours }
        if dst.sleepAwakeMinutes == nil { dst.sleepAwakeMinutes = src.sleepAwakeMinutes }
        if dst.sleepOnset == nil { dst.sleepOnset = src.sleepOnset }
        if dst.sleepInterruptionCount == nil { dst.sleepInterruptionCount = src.sleepInterruptionCount }
        if dst.sleepScore == nil { dst.sleepScore = src.sleepScore }

        if dst.workoutDataJSON == nil { dst.workoutDataJSON = src.workoutDataJSON }
        if dst.workoutCount == nil { dst.workoutCount = src.workoutCount }
        if dst.totalWorkoutMinutes == nil { dst.totalWorkoutMinutes = src.totalWorkoutMinutes }
        if dst.workoutIntensityScore == nil { dst.workoutIntensityScore = src.workoutIntensityScore }
        if dst.restingHeartRate == nil { dst.restingHeartRate = src.restingHeartRate }
        if dst.averageHeartRate == nil { dst.averageHeartRate = src.averageHeartRate }

        if dst.screenTimeSeconds == nil { dst.screenTimeSeconds = src.screenTimeSeconds }
        if dst.pickups == nil { dst.pickups = src.pickups }

        if let srcPhotos = src.attachedPhotoData, !srcPhotos.isEmpty {
            var combined = dst.attachedPhotoData ?? []
            combined.append(contentsOf: srcPhotos.filter { !combined.contains($0) })
            dst.attachedPhotoData = combined
        }
        if let srcIDs = src.autoPhotoIdentifiers, !srcIDs.isEmpty {
            var combined = dst.autoPhotoIdentifiers ?? []
            combined.append(contentsOf: srcIDs.filter { !combined.contains($0) })
            dst.autoPhotoIdentifiers = combined
        }
        if dst.mapThumbnailData == nil { dst.mapThumbnailData = src.mapThumbnailData }

        if src.hasUserSubmitted { dst.hasUserSubmitted = true }
        if dst.firstSubmittedAt == nil { dst.firstSubmittedAt = src.firstSubmittedAt }
        if src.createdAt < dst.createdAt { dst.createdAt = src.createdAt }
    }
}
