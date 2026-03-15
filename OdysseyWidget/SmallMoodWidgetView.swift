import SwiftUI
import WidgetKit

struct SmallMoodWidgetView: View {
    let entry: MoodWidgetEntry

    private let moodOptions: [(emoji: String, value: Int)] = [
        ("😣", 2), ("😕", 4), ("😐", 5), ("😊", 7), ("🤩", 9)
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
            Text("How are you?")
                .font(.caption.bold())
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(moodOptions, id: \.value) { option in
                    Button(intent: LogMoodIntent(moodValue: option.value)) {
                        Text(option.emoji)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
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
            Text(emojiForMood(mood))
                .font(.largeTitle)

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

    private func emojiForMood(_ value: Int) -> String {
        switch value {
        case 1...2: return "😣"
        case 3...4: return "😕"
        case 5...6: return "😐"
        case 7...8: return "😊"
        default: return "🤩"
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
