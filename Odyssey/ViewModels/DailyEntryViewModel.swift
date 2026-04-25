import Foundation
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DailyEntry")

@MainActor
@Observable
final class DailyEntryViewModel {
    var hasSubmittedData = false
    var submissionMessage = ""

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkForTodayEntry()
    }

    private var repository: DailyEntryRepository {
        DailyEntryRepository(context: modelContext)
    }

    func checkForTodayEntry() {
        let today = fetchTodayEntry()
        hasSubmittedData = today?.hasUserSubmitted ?? false
        if hasSubmittedData {
            submissionMessage = "Already completed entry for today."
        }
    }

    func fetchTodayEntry() -> DailyEntry? {
        fetchEntry(for: Date())
    }

    func fetchEntry(for date: Date) -> DailyEntry? {
        do {
            return try repository.fetchEntry(for: date)
        } catch {
            logger.error("Failed to fetch entry for \(date): \(error)")
            return nil
        }
    }

    func fetchEntries(from startDate: Date, to endDate: Date) -> [DailyEntry] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .hour, value: -36, to: cal.startOfDay(for: startDate)) ?? startDate
        let end = cal.date(byAdding: .hour, value: 60, to: cal.startOfDay(for: endDate)) ?? endDate
        let predicate = #Predicate<DailyEntry> { $0.date >= start && $0.date <= end }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        let results = (try? modelContext.fetch(descriptor)) ?? []
        let startDayBound = cal.startOfDay(for: startDate)
        let endDayBound = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        return results.filter { entry in
            let day = entry.date
            return (cal.isDate(day, inSameDayAs: startDate) || day >= startDayBound)
                && (cal.isDate(day, inSameDayAs: endDate) || day < endDayBound)
        }
    }

    func fetchAllEntries() -> [DailyEntry] {
        let descriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func submitData(
        feeling: Int,
        singleWordFeeling: String,
        feelingColorHex: String,
        sleepQuality: Int,
        gratitude: String,
        win: String,
        tension: String,
        journalEntry: String,
        drinks: Int
    ) {
        do {
            let entry = try repository.fetchOrCreateToday()

            entry.feeling = feeling
            entry.singleWordFeeling = singleWordFeeling
            entry.feelingColorHex = feelingColorHex
            entry.sleepQuality = sleepQuality
            entry.gratitude = gratitude
            entry.win = win
            entry.tension = tension
            entry.journalEntry = journalEntry
            entry.drinks = drinks
            entry.hasUserSubmitted = true
            if entry.firstSubmittedAt == nil {
                entry.firstSubmittedAt = Date()
            }
            entry.updatedAt = Date()

            try modelContext.save()
            hasSubmittedData = true
            submissionMessage = "Successfully saved today's entry."
            NotificationCenter.default.post(name: .didSaveFirstEntry, object: nil)
        } catch {
            logger.error("Failed to save entry: \(error)")
        }
    }

    /// One fetch, bucketed into slots for the last 7 days. Timezone-robust:
    /// entries authored in a different zone still land in their local-calendar
    /// slot via `Calendar.isDate(_:inSameDayAs:)`.
    func fetchWeekEntries() -> [DailyEntry?] {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let weekStart = cal.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let windowStart = cal.date(byAdding: .hour, value: -36, to: weekStart) ?? todayStart
        let windowEnd = cal.date(byAdding: .hour, value: 60, to: todayStart) ?? todayStart

        let predicate = #Predicate<DailyEntry> { $0.date >= windowStart && $0.date < windowEnd }
        let results = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []

        return (0 ..< 7).reversed().map { offset in
            let target = now.daysAgo(offset)
            let matches = results.filter { cal.isDate($0.date, inSameDayAs: target) }
            return DailyEntryRepository.pickPrimary(matches)
        }
    }

    func updateLocation() async throws {
        let entry = try repository.fetchOrCreateToday()

        let service = LocationCaptureService()
        let snapshot = try await service.captureCurrentLocation()

        entry.latitude = snapshot.latitude
        entry.longitude = snapshot.longitude
        entry.city = snapshot.city
        entry.state = snapshot.state
        entry.country = snapshot.country
        entry.locationCapturedAt = Date()
        entry.updatedAt = Date()

        try modelContext.save()
    }

    var currentStreak: Int {
        fetchAllEntries().currentStreak
    }
}
