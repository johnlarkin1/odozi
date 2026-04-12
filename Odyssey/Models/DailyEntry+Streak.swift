import Foundation

extension Array where Element == DailyEntry {
    /// Computes the current streak of consecutive days with prompt data,
    /// counting backwards from today. If today's entry doesn't have prompt
    /// data yet (user hasn't journaled today), counts from yesterday so the
    /// streak doesn't appear broken mid-day.
    var currentStreak: Int {
        let sorted = self.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var expectedDate = today

        // Check if today's entry has prompt data
        let todayHasPromptData = sorted.first(where: {
            calendar.startOfDay(for: $0.date) == today
        })?.hasPromptData ?? false

        // If today isn't filled in yet, start counting from yesterday
        if !todayHasPromptData {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            expectedDate = yesterday
        }

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
        let sorted = filter { $0.hasPromptData }.sorted { $0.date < $1.date }
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
        filter { $0.hasPromptData }
            .reduce(0) { $0 + $1.journalEntry.split(separator: " ").count }
    }

    var uniqueCityCount: Int {
        Set(compactMap(\.city)).count
    }

    var uniqueCountryCount: Int {
        Set(compactMap(\.country)).count
    }

    var uniqueFeelingColorCount: Int {
        Set(filter(\.hasCustomFeelingColor).map(\.feelingColorHex)).count
    }

    var uniqueGratitudeCount: Int {
        Set(map(\.gratitude).filter { !$0.isEmpty }).count
    }
}
