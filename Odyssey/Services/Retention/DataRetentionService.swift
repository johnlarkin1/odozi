import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataRetention")

enum DataRetentionService {
    /// UserDefaults key storing the Date when the user last dismissed the retention alert.
    static let dismissedAtKey = "retentionAlertDismissedAt"

    /// How long to wait after the user dismisses before re-prompting (30 days).
    private static let cooldownDays = 30

    // MARK: - Phase 1: Count

    /// Returns the number of entries older than 1 year for non-account users.
    /// Respects a 30-day cooldown after the user dismisses the alert — returns 0 during cooldown.
    static func countOldEntries(context: ModelContext, hasAccount: Bool) -> Int {
        guard !hasAccount else { return 0 }

        // Cooldown: if user dismissed less than 30 days ago, don't prompt again
        if let dismissedAt = UserDefaults.standard.object(forKey: dismissedAtKey) as? Date,
           let cooldownEnd = Calendar.current.date(byAdding: .day, value: cooldownDays, to: dismissedAt),
           Date() < cooldownEnd {
            return 0
        }

        guard let cutoffDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else {
            return 0
        }

        let predicate = #Predicate<DailyEntry> { $0.date < cutoffDate }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let count = try? context.fetchCount(descriptor) else {
            return 0
        }

        return count
    }

    // MARK: - Phase 2: Delete

    /// Deletes all entries older than 1 year. Call only after user confirmation.
    static func performCleanup(context: ModelContext) {
        guard let cutoffDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else {
            return
        }

        let predicate = #Predicate<DailyEntry> { $0.date < cutoffDate }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let oldEntries = try? context.fetch(descriptor),
              !oldEntries.isEmpty
        else {
            return
        }

        for entry in oldEntries {
            context.delete(entry)
        }

        do {
            try context.save()
            logger.info("Cleaned up \(oldEntries.count) entries older than 1 year")
        } catch {
            logger.error("Failed to save after retention cleanup: \(error)")
        }
    }

    // MARK: - Dismissal

    /// Records that the user dismissed the retention alert, starting the 30-day cooldown.
    static func recordDismissal() {
        UserDefaults.standard.set(Date(), forKey: dismissedAtKey)
    }
}
