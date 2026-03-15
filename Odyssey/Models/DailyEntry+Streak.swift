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
                guard let prev = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                expectedDate = prev
            } else if entryDate < expectedDate {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        let sorted = self.filter { $0.hasPromptData }.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        var longest = 0
        var current = 0
        var lastDate: Date?

        for entry in sorted {
            let entryDate = calendar.startOfDay(for: entry.date)
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entryDate).day ?? 0
                if daysBetween == 1 {
                    current += 1
                } else if daysBetween > 1 {
                    current = 1
                }
            } else {
                current = 1
            }
            longest = Swift.max(longest, current)
            lastDate = entryDate
        }
        return longest
    }

    var totalJournalWordCount: Int {
        self.filter { $0.hasPromptData }
            .reduce(0) { $0 + $1.journalEntry.split(separator: " ").count }
    }

    var uniqueCityCount: Int {
        Set(self.compactMap(\.city)).count
    }

    var uniqueCountryCount: Int {
        Set(self.compactMap(\.country)).count
    }

    var uniqueFeelingColorCount: Int {
        Set(self.map(\.feelingColorHex).filter { $0 != "#FFFFFF" }).count
    }

    var uniqueGratitudeCount: Int {
        Set(self.map(\.gratitude).filter { !$0.isEmpty }).count
    }
}
