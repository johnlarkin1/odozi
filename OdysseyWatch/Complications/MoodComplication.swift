import SwiftData
import SwiftUI
import WidgetKit

struct MoodTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> MoodTimelineEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (MoodTimelineEntry) -> Void) {
        let entry = fetchCurrentEntry() ?? .empty
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MoodTimelineEntry>) -> Void) {
        let entry = fetchCurrentEntry() ?? .empty

        // Refresh at midnight so the complication updates for the new day
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> MoodTimelineEntry? {
        guard let container = try? DataContainer.create() else { return nil }
        let context = ModelContext(container)

        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let dailyEntry = try? context.fetch(descriptor).first,
              dailyEntry.hasUserSubmitted
        else {
            return .empty
        }

        let streak = calculateStreak(context: context)
        return MoodTimelineEntry(
            date: .now,
            moodScore: dailyEntry.feeling,
            streakDays: streak,
            hasEntry: true
        )
    }

    private func calculateStreak(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor) else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.date)
            if entryDay == checkDate && entry.hasUserSubmitted {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else if entryDay < checkDate {
                break
            }
        }
        return streak
    }
}

struct MoodComplication: Widget {
    let kind = "MoodComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodTimelineProvider()) { entry in
            MoodComplicationView(entry: entry)
        }
        .configurationDisplayName("Today's Mood")
        .description("Shows your current mood score and streak")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}
