import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataRetention")

enum DataRetentionService {
    static func performCleanupIfNeeded(modelContext: ModelContext, hasAccount: Bool) {
        // Users with accounts skip local cleanup — their data is backed up
        guard !hasAccount else { return }

        guard let cutoffDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else {
            return
        }

        let predicate = #Predicate<DailyEntry> { $0.date < cutoffDate }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let oldEntries = try? modelContext.fetch(descriptor),
              !oldEntries.isEmpty else {
            return
        }

        for entry in oldEntries {
            modelContext.delete(entry)
        }

        do {
            try modelContext.save()
            logger.info("Cleaned up \(oldEntries.count) entries older than 1 year")
        } catch {
            logger.error("Failed to save after retention cleanup: \(error)")
        }
    }
}
