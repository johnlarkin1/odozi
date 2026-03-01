import Foundation

extension Array where Element == DailyEntry {
    /// Computes the current streak of consecutive days with prompt data,
    /// counting backwards from today.
    var currentStreak: Int {
        let sorted = self.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        for entry in sorted {
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
