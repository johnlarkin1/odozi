import Foundation
import SwiftData

struct WeeklyDigestData: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let daysJournaled: Int
    let totalDays: Int
    let averageMood: Double
    let previousWeekAverageMood: Double?
    let moodTrendDelta: Double?
    let topEmotion: String?
    let currentStreak: Int
    let averageSleepQuality: Double?
    let totalSteps: Int
    let totalDrinks: Int
    let averageSleepHours: Double?
    let averageScreenTimeHours: Double?

    var moodTrendSymbol: String {
        guard let delta = moodTrendDelta else { return "" }
        if delta > 0.3 { return "↑" }
        if delta < -0.3 { return "↓" }
        return "→"
    }

    var hasData: Bool { daysJournaled > 0 }

    static func empty(endDate: Date) -> WeeklyDigestData {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!
        return WeeklyDigestData(
            weekStartDate: start,
            weekEndDate: endDate,
            daysJournaled: 0,
            totalDays: 7,
            averageMood: 0,
            previousWeekAverageMood: nil,
            moodTrendDelta: nil,
            topEmotion: nil,
            currentStreak: 0,
            averageSleepQuality: nil,
            totalSteps: 0,
            totalDrinks: 0,
            averageSleepHours: nil,
            averageScreenTimeHours: nil
        )
    }
}

enum WeeklyDigestService {
    @MainActor
    static func computeDigest(context: ModelContext, endDate: Date = Date()) -> WeeklyDigestData {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endDate)!)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!
        let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!

        // Fetch current week entries
        let currentWeekEntries: [DailyEntry] = fetchEntries(context: context, from: weekStart, to: endOfDay)
        let promptEntries: [DailyEntry] = currentWeekEntries.filter { $0.hasPromptData }

        // Fetch previous week entries for trend
        let prevWeekEntries: [DailyEntry] = fetchEntries(context: context, from: prevWeekStart, to: weekStart)
        let prevPromptEntries: [DailyEntry] = prevWeekEntries.filter { $0.hasPromptData }

        // Mood averages
        let avgMood = promptEntries.isEmpty ? 0 : Double(promptEntries.map { $0.feeling }.reduce(0, +)) / Double(promptEntries.count)
        let prevAvgMood: Double? = prevPromptEntries.isEmpty ? nil : Double(prevPromptEntries.map { $0.feeling }.reduce(0, +)) / Double(prevPromptEntries.count)
        let delta: Double? = prevAvgMood.map { avgMood - $0 }

        // Top emotion
        let emotions = promptEntries.map { $0.singleWordFeeling }.filter { !$0.isEmpty }
        let topEmotion = emotions.isEmpty ? nil : Dictionary(grouping: emotions, by: { $0.lowercased() })
            .max(by: { $0.value.count < $1.value.count })?
            .value.first

        // Streak — fetch all entries for accurate streak calc
        let allDescriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\DailyEntry.date, order: .reverse)])
        let allEntries: [DailyEntry] = (try? context.fetch(allDescriptor)) ?? []
        let streak = allEntries.currentStreak

        // Sleep quality average
        let sleepQualities = promptEntries.map { $0.sleepQuality }
        let avgSleepQuality: Double? = sleepQualities.isEmpty ? nil : Double(sleepQualities.reduce(0, +)) / Double(sleepQualities.count)

        // Steps total
        let totalSteps = currentWeekEntries.compactMap { $0.stepCount }.reduce(0, +)

        // Drinks total
        let totalDrinks = promptEntries.map { $0.drinks }.reduce(0, +)

        // Sleep hours average
        let sleepHoursValues = currentWeekEntries.compactMap { $0.sleepHours }
        let avgSleepHours: Double? = sleepHoursValues.isEmpty ? nil : sleepHoursValues.reduce(0, +) / Double(sleepHoursValues.count)

        // Screen time average
        let screenTimeValues = currentWeekEntries.compactMap { $0.screenTimeSeconds }
        let avgScreenTimeHours: Double? = screenTimeValues.isEmpty ? nil : (screenTimeValues.reduce(0, +) / Double(screenTimeValues.count)) / 3600.0

        return WeeklyDigestData(
            weekStartDate: weekStart,
            weekEndDate: endDate,
            daysJournaled: promptEntries.count,
            totalDays: 7,
            averageMood: avgMood,
            previousWeekAverageMood: prevAvgMood,
            moodTrendDelta: delta,
            topEmotion: topEmotion,
            currentStreak: streak,
            averageSleepQuality: avgSleepQuality,
            totalSteps: totalSteps,
            totalDrinks: totalDrinks,
            averageSleepHours: avgSleepHours,
            averageScreenTimeHours: avgScreenTimeHours
        )
    }

    private static func fetchEntries(context: ModelContext, from start: Date, to end: Date) -> [DailyEntry] {
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sortBy: [SortDescriptor(\DailyEntry.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
