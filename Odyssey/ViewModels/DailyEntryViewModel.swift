import SwiftUI
import SwiftData
import os

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

    func checkForTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let results = try modelContext.fetch(descriptor)
            hasSubmittedData = !results.isEmpty
            if hasSubmittedData {
                submissionMessage = "Already completed entry for today."
            }
        } catch {
            logger.error("Failed to fetch today's entry: \(error)")
        }
    }

    func fetchTodayEntry() -> DailyEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
    }

    func fetchEntry(for date: Date) -> DailyEntry? {
        let targetDate = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyEntry> { $0.date == targetDate }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
    }

    func fetchEntries(from startDate: Date, to endDate: Date) -> [DailyEntry] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let predicate = #Predicate<DailyEntry> { $0.date >= start && $0.date <= end }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])

        return (try? modelContext.fetch(descriptor)) ?? []
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
        let today = Calendar.current.startOfDay(for: Date())
        let entry: DailyEntry

        if let existing = fetchTodayEntry() {
            entry = existing
        } else {
            entry = DailyEntry(date: today)
            modelContext.insert(entry)
        }

        entry.feeling = feeling
        entry.singleWordFeeling = singleWordFeeling
        entry.feelingColorHex = feelingColorHex
        entry.sleepQuality = sleepQuality
        entry.gratitude = gratitude
        entry.win = win
        entry.tension = tension
        entry.journalEntry = journalEntry
        entry.drinks = drinks
        entry.updatedAt = Date()
        entry.needsSync = true

        do {
            try modelContext.save()
            hasSubmittedData = true
            submissionMessage = "Successfully saved today's entry."
            NotificationCenter.default.post(name: .didSaveFirstEntry, object: nil)
        } catch {
            logger.error("Failed to save entry: \(error)")
        }
    }

    func fetchWeekEntries() -> [DailyEntry?] {
        (0..<7).reversed().map { fetchEntry(for: Date().daysAgo($0)) }
    }

    func updateLocation() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let entry: DailyEntry
        if let existing = fetchTodayEntry() {
            entry = existing
        } else {
            entry = DailyEntry(date: today)
            modelContext.insert(entry)
        }

        let service = LocationCaptureService()
        let snapshot = try await service.captureCurrentLocation()

        entry.latitude = snapshot.latitude
        entry.longitude = snapshot.longitude
        entry.city = snapshot.city
        entry.state = snapshot.state
        entry.country = snapshot.country
        entry.updatedAt = Date()

        try modelContext.save()
    }

    var currentStreak: Int {
        let entries = fetchAllEntries().sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        for entry in entries {
            let entryDate = calendar.startOfDay(for: entry.date)
            if entryDate == expectedDate && entry.hasPromptData {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if entryDate < expectedDate {
                break
            }
        }
        return streak
    }
}
