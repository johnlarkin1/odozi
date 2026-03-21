import SwiftData
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    var entries: [DailyEntry] = []
    var dateRange: DateRange = .month
    var achievementUnlockedCount: Int = 0
    var achievementTotalCount: Int = 0

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
        entries.currentStreak
    }

    var longestStreak: Int {
        entries.longestStreak
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

    // MARK: - Body Metrics

    var averageSteps: Double {
        let valid = filteredEntries.compactMap(\.stepCount)
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0, +)) / Double(valid.count)
    }

    var averageWalkingDistanceMiles: Double {
        let valid = filteredEntries.compactMap(\.walkingDistanceMeters)
        guard !valid.isEmpty else { return 0 }
        let totalMeters = valid.reduce(0, +)
        return (totalMeters / Double(valid.count)) / 1609.34
    }

    var averageSleepHours: Double {
        let valid = filteredEntries.compactMap(\.sleepHours)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    var totalDrinks: Int {
        filteredEntries.reduce(0) { $0 + $1.drinks }
    }

    // MARK: - World Metrics

    var averageScreenTimeHours: Double {
        let valid = filteredEntries.compactMap(\.screenTimeSeconds)
        guard !valid.isEmpty else { return 0 }
        let totalSeconds = valid.reduce(0, +)
        return (totalSeconds / Double(valid.count)) / 3600.0
    }

    var averagePickups: Double {
        let valid = filteredEntries.compactMap(\.pickups)
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0, +)) / Double(valid.count)
    }

    // MARK: - Sparkline & Trend

    func sparklineData(for metric: MetricDefinition) -> [(Date, Double)] {
        filteredEntries.compactMap { entry in
            guard let value = metric.value(from: entry) else { return nil }
            return (entry.date, value)
        }.sorted { $0.0 < $1.0 }
    }

    func trend(for metric: MetricDefinition) -> TrendCalculator.Trend {
        TrendCalculator.trend(for: metric, entries: filteredEntries)
    }

    func average(for metric: MetricDefinition) -> Double {
        let values = filteredEntries.compactMap { metric.value(from: $0) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Correlation

    var strongestCorrelation: CorrelationService.CorrelationResult? {
        CorrelationService.strongestCorrelation(entries: filteredEntries)
    }

    func loadEntries() {
        let descriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        loadAchievements()
    }

    func loadAchievements() {
        let service = AchievementService(modelContext: modelContext)
        achievementUnlockedCount = service.unlockedCount()
        achievementTotalCount = service.totalCount()
    }
}
