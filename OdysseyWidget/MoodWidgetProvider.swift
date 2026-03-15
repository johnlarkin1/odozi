import WidgetKit
import SwiftData

struct MoodWidgetEntry: TimelineEntry {
    let date: Date
    let todayMood: Int?
    let hasUserSubmitted: Bool
    let currentStreak: Int
}

struct MoodWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(date: .now, todayMood: 7, hasUserSubmitted: true, currentStreak: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodWidgetEntry>) -> Void) {
        let entry = fetchEntry()

        // Reload at midnight so the widget resets for the new day
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func fetchEntry() -> MoodWidgetEntry {
        guard let container = try? WidgetDataAccess.makeContainer() else {
            return MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 0)
        }

        let context = ModelContext(container)
        let todayEntry = WidgetDataAccess.fetchTodayEntry(context: context)
        let streak = WidgetDataAccess.calculateStreak(context: context)

        let mood: Int? = todayEntry.map { $0.feeling }
        let submitted = todayEntry?.hasUserSubmitted ?? false

        return MoodWidgetEntry(
            date: .now,
            todayMood: mood,
            hasUserSubmitted: submitted,
            currentStreak: streak
        )
    }
}
