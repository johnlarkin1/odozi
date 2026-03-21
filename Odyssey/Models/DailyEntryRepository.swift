import Foundation
import SwiftData

@MainActor
struct DailyEntryRepository {
    let context: ModelContext

    /// Fetches today's entry, or creates one if none exists.
    func fetchOrCreateToday() throws -> DailyEntry {
        let today = Calendar.current.startOfDay(for: Date())
        return try fetchOrCreate(for: today)
    }

    func fetchOrCreate(for date: Date) throws -> DailyEntry {
        let day = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyEntry> { $0.date == day }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let entry = DailyEntry(date: day)
        context.insert(entry)
        return entry
    }

    func fetchEntry(for date: Date) throws -> DailyEntry? {
        let day = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DailyEntry> { $0.date == day }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
