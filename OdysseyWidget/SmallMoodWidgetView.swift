import SwiftUI
import WidgetKit

struct SmallMoodWidgetView: View {
    let entry: MoodWidgetEntry

    private let moodOptions: [(value: Int, label: String)] = [
        (2, "Low"), (4, "Meh"), (5, "OK"), (7, "Good"), (9, "Great")
    ]

    var body: some View {
        Group {
            if let mood = entry.todayMood {
                completedState(mood: mood)
            } else {
                promptState
            }
        }
        .containerBackground(for: .widget) {
            Color.deepSpaceBlue
        }
        .widgetURL(URL(string: "odyssey://guided-prompt"))
    }

    // MARK: - Not Logged

    private var promptState: some View {
        VStack(spacing: 8) {
            Text("Odyssey")
                .font(.caption2.bold())
                .foregroundStyle(Color.accentAmber)

            Text("How are you?")
                .font(.caption.bold())
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(moodOptions, id: \.value) { option in
                    Button(intent: LogMoodIntent(moodValue: option.value)) {
                        Circle()
                            .fill(Color.moodGradient(for: option.value))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("\(option.value)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if entry.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentAmber)
                    Text("\(entry.currentStreak)")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentAmber)
                }
            }
        }
        .padding(4)
    }

    // MARK: - Completed

    private func completedState(mood: Int) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.moodGradient(for: mood))
                .frame(width: 52, height: 52)
                .overlay(
                    Text("\(mood)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )

            Text("Mood: \(mood)/10")
                .font(.caption.bold())
                .foregroundStyle(.white)

            if entry.hasUserSubmitted {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.successGreen)
            } else {
                Text("Tap to journal")
                    .font(.caption2)
                    .foregroundStyle(Color.accentAmber)
            }

            if entry.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentAmber)
                    Text("\(entry.currentStreak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Small - Not Logged", as: .systemSmall) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 3)
}

#Preview("Small - Mood Logged", as: .systemSmall) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: 7, hasUserSubmitted: false, currentStreak: 5)
}

#Preview("Small - Fully Submitted", as: .systemSmall) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: 9, hasUserSubmitted: true, currentStreak: 12)
}
