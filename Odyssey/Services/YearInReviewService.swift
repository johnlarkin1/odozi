import Foundation
import SwiftData

struct YearInReviewData {
    let year: Int
    let totalEntries: Int
    let totalDaysInYear: Int
    let averageMood: Double
    let averageSleep: Double
    let totalSteps: Int
    let totalDrinks: Int
    let moodByMonth: [(month: String, avgMood: Double)]
    let topCities: [(city: String, count: Int)]
    let feelingWordCloud: [(word: String, count: Int)]
    let longestStreak: Int
    let bestDay: DailyEntry?
    let allColors: [String]
    let topGratitudes: [String]

    var completionPercentage: Double {
        Double(totalEntries) / Double(totalDaysInYear) * 100
    }
}

final class YearInReviewService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func generate(for year: Int) -> YearInReviewData {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

        let predicate = #Predicate<DailyEntry> { $0.date >= startOfYear && $0.date <= endOfYear }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        let withData = entries.filter { $0.hasPromptData }

        let totalDays = calendar.dateComponents([.day], from: startOfYear, to: endOfYear).day! + 1

        let avgMood = withData.isEmpty ? 0 : Double(withData.reduce(0) { $0 + $1.feeling }) / Double(withData.count)
        let avgSleep = withData.isEmpty ? 0 : Double(withData.reduce(0) { $0 + $1.sleepQuality }) / Double(withData.count)
        let totalSteps = entries.compactMap(\.stepCount).reduce(0, +)
        let totalDrinks = entries.reduce(0) { $0 + $1.drinks }

        // Mood by month
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        var monthMoods: [Int: [Int]] = [:]
        for entry in withData {
            let month = calendar.component(.month, from: entry.date)
            monthMoods[month, default: []].append(entry.feeling)
        }
        let moodByMonth = (1...12).map { month -> (String, Double) in
            let date = calendar.date(from: DateComponents(year: year, month: month))!
            let label = monthFormatter.string(from: date)
            let moods = monthMoods[month] ?? []
            let avg = moods.isEmpty ? 0 : Double(moods.reduce(0, +)) / Double(moods.count)
            return (label, avg)
        }

        // Top cities
        var cityCounts: [String: Int] = [:]
        for entry in entries {
            if let city = entry.city {
                cityCounts[city, default: 0] += 1
            }
        }
        let topCities = cityCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        // Word cloud
        var wordCounts: [String: Int] = [:]
        for entry in entries where !entry.singleWordFeeling.isEmpty {
            let word = entry.singleWordFeeling.lowercased()
            wordCounts[word, default: 0] += 1
        }
        let wordCloud = wordCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }

        // Longest streak
        let sorted = withData.sorted { $0.date < $1.date }
        var longest = 0
        var current = 0
        var lastDate: Date?
        for entry in sorted {
            let entryDate = calendar.startOfDay(for: entry.date)
            if let last = lastDate {
                if calendar.dateComponents([.day], from: last, to: entryDate).day == 1 {
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

        // Best day
        let bestDay = withData.max(by: { $0.feeling < $1.feeling })

        // All colors
        let allColors = entries.filter { $0.feelingColorHex != "#FFFFFF" }.map(\.feelingColorHex)

        // Top gratitudes
        let gratitudes = entries.map(\.gratitude).filter { !$0.isEmpty }.prefix(5).map { String($0) }

        return YearInReviewData(
            year: year,
            totalEntries: withData.count,
            totalDaysInYear: totalDays,
            averageMood: avgMood,
            averageSleep: avgSleep,
            totalSteps: totalSteps,
            totalDrinks: totalDrinks,
            moodByMonth: moodByMonth,
            topCities: topCities,
            feelingWordCloud: wordCloud,
            longestStreak: longest,
            bestDay: bestDay,
            allColors: allColors,
            topGratitudes: gratitudes
        )
    }
}
