import SwiftUI
import SwiftData

@Observable
final class InsightsViewModel {
    var entries: [DailyEntry] = []
    var dateRange: DateRange = .month

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var filteredEntries: [DailyEntry] {
        let start = Calendar.current.startOfDay(for: dateRange.startDate)
        return entries.filter { $0.date >= start }.sorted { $0.date < $1.date }
    }

    var averageMood: Double {
        let valid = filteredEntries.filter { $0.hasPromptData }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0) { $0 + $1.feeling }) / Double(valid.count)
    }

    var averageSleep: Double {
        let valid = filteredEntries.filter { $0.hasPromptData }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0) { $0 + $1.sleepQuality }) / Double(valid.count)
    }

    var currentStreak: Int {
        let sorted = entries.sorted { $0.date > $1.date }
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

    var longestStreak: Int {
        let sorted = entries.filter { $0.hasPromptData }.sorted { $0.date < $1.date }
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
                } else {
                    current = 1
                }
            } else {
                current = 1
            }
            longest = max(longest, current)
            lastDate = entryDate
        }
        return longest
    }

    var topFeelingWords: [(word: String, count: Int)] {
        var wordCounts: [String: Int] = [:]
        for entry in filteredEntries where !entry.singleWordFeeling.isEmpty {
            let word = entry.singleWordFeeling.lowercased()
            wordCounts[word, default: 0] += 1
        }
        return wordCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    var feelingColors: [String] {
        filteredEntries
            .filter { $0.feelingColorHex != "#FFFFFF" }
            .map { $0.feelingColorHex }
    }

    func loadEntries() {
        let descriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }
}
