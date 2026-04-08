import WidgetKit

struct MoodTimelineEntry: TimelineEntry {
    let date: Date
    let moodScore: Int?
    let streakDays: Int
    let hasEntry: Bool

    static var placeholder: MoodTimelineEntry {
        MoodTimelineEntry(date: .now, moodScore: 7, streakDays: 5, hasEntry: true)
    }

    static var empty: MoodTimelineEntry {
        MoodTimelineEntry(date: .now, moodScore: nil, streakDays: 0, hasEntry: false)
    }
}
