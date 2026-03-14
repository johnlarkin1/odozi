import SwiftData
import Foundation

enum WidgetDataAccess {
    static func makeContainer() throws -> ModelContainer {
        try DataContainer.create()
    }

    static func fetchTodayEntry(context: ModelContext) -> DailyEntry? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func recordMood(_ value: Int, context: ModelContext) throws {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        descriptor.fetchLimit = 1

        let entry: DailyEntry
        if let existing = try context.fetch(descriptor).first {
            entry = existing
        } else {
            entry = DailyEntry(date: startOfDay)
            context.insert(entry)
        }

        entry.feeling = value
        entry.updatedAt = Date()
        // Do NOT set hasUserSubmitted — that's for the full guided flow
        try context.save()
    }

    static func calculateStreak(context: ModelContext) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            var descriptor = FetchDescriptor<DailyEntry>(
                predicate: #Predicate<DailyEntry> { entry in
                    entry.date >= checkDate && entry.date < nextDay && entry.hasUserSubmitted == true
                }
            )
            descriptor.fetchLimit = 1

            if let count = try? context.fetchCount(descriptor), count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if streak == 0 {
                // Today might not be submitted yet — check yesterday
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            } else {
                break
            }
        }

        return streak
    }
}
