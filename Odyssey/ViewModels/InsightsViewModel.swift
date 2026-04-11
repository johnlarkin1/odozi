import SwiftData
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    var entries: [DailyEntry] = [] {
        didSet { invalidateCache() }
    }

    var dateRange: DateRange = .month {
        didSet { invalidateCache() }
    }

    var achievementUnlockedCount: Int = 0
    var achievementTotalCount: Int = 0

    private let modelContext: ModelContext

    // MARK: - Cache

    private var _cachedFiltered: [DailyEntry]?
    private var _cachedTopFeelingWords: [(word: String, count: Int)]?
    private var _cachedCorrelation: CorrelationService.CorrelationResult??
    private var _cachedSparkline: [MetricDefinition: [(Date, Double)]] = [:]
    private var _cachedTrend: [MetricDefinition: TrendCalculator.Trend] = [:]
    private var _cachedAverage: [MetricDefinition: Double] = [:]

    private func invalidateCache() {
        _cachedFiltered = nil
        _cachedTopFeelingWords = nil
        _cachedCorrelation = nil
        _cachedSparkline.removeAll()
        _cachedTrend.removeAll()
        _cachedAverage.removeAll()
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var filteredEntries: [DailyEntry] {
        if let cached = _cachedFiltered { return cached }
        let start = Calendar.current.startOfDay(for: dateRange.startDate)
        let result = entries.filter { $0.date >= start }.sorted { $0.date < $1.date }
        _cachedFiltered = result
        return result
    }

    var averageMood: Double {
        let values = filteredEntries.filter(\.hasPromptData).map(\.feeling).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    var averageSleep: Double {
        let values = filteredEntries.filter(\.hasPromptData).map(\.sleepQuality).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    var currentStreak: Int {
        entries.currentStreak
    }

    var longestStreak: Int {
        entries.longestStreak
    }

    var topFeelingWords: [(word: String, count: Int)] {
        if let cached = _cachedTopFeelingWords { return cached }
        var wordCounts: [String: Int] = [:]
        for entry in filteredEntries where !entry.singleWordFeeling.isEmpty {
            let word = entry.singleWordFeeling.lowercased()
            wordCounts[word, default: 0] += 1
        }
        let result = wordCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
        _cachedTopFeelingWords = result
        return result
    }

    var feelingColors: [String] {
        filteredEntries
            .filter { $0.hasPromptData && $0.feelingColorHex != "#FFFFFF" }
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
        filteredEntries.filter(\.hasPromptData).reduce(0) { $0 + $1.drinks }
    }

    // MARK: - Workout & Heart Rate Metrics

    var averageWorkoutMinutes: Double {
        let valid = filteredEntries.compactMap(\.totalWorkoutMinutes)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    var averageWorkoutIntensity: Double {
        let valid = filteredEntries.compactMap(\.workoutIntensityScore)
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0, +)) / Double(valid.count)
    }

    var averageRestingHeartRate: Double {
        let valid = filteredEntries.compactMap(\.restingHeartRate)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
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

    // MARK: - Sparkline & Trend (cached per metric)

    func sparklineData(for metric: MetricDefinition) -> [(Date, Double)] {
        if let cached = _cachedSparkline[metric] { return cached }
        let result: [(Date, Double)] = filteredEntries.compactMap { entry in
            guard let value = metric.value(from: entry) else { return nil }
            return (entry.date, value)
        }.sorted { $0.0 < $1.0 }
        _cachedSparkline[metric] = result
        return result
    }

    func trend(for metric: MetricDefinition) -> TrendCalculator.Trend {
        if let cached = _cachedTrend[metric] { return cached }
        let result = TrendCalculator.trend(for: metric, entries: filteredEntries)
        _cachedTrend[metric] = result
        return result
    }

    func average(for metric: MetricDefinition) -> Double {
        if let cached = _cachedAverage[metric] { return cached }
        let values = filteredEntries.compactMap { metric.value(from: $0) }
        guard !values.isEmpty else { return 0 }
        let result = values.reduce(0, +) / Double(values.count)
        _cachedAverage[metric] = result
        return result
    }

    // MARK: - Correlation (cached)

    var strongestCorrelation: CorrelationService.CorrelationResult? {
        if let cached = _cachedCorrelation { return cached }
        let result = CorrelationService.strongestCorrelation(entries: filteredEntries)
        _cachedCorrelation = .some(result)
        return result
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
