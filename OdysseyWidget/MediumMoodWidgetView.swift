import SwiftUI
import WidgetKit

struct MediumMoodWidgetView: View {
    let entry: MoodWidgetEntry

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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Odyssey")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentAmber)
                    Text("How are you feeling?")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                if entry.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentAmber)
                        Text("\(entry.currentStreak)")
                            .bold()
                            .foregroundStyle(Color.accentAmber)
                    }
                    .font(.caption)
                }
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    Button(intent: LogMoodIntent(moodValue: value)) {
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.moodGradient(for: value))
                                .frame(height: 32)
                            Text("\(value)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(4)
    }

    // MARK: - Completed

    private func completedState(mood: Int) -> some View {
        let moodColor = Color.moodGradient(for: mood)

        return HStack(spacing: 16) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [moodColor, moodColor.opacity(0.15)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 45
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text("\(mood)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("\(mood)/10")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Odyssey")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentAmber)
                    Spacer()
                }

                if entry.hasUserSubmitted {
                    Label("Journal complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.successGreen)
                } else {
                    Label("Tap to finish journaling", systemImage: "pencil.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentAmber)
                }

                if entry.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentAmber)
                        Text("\(entry.currentStreak) day streak")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                // Mini mood bar showing selected value
                HStack(spacing: 2) {
                    ForEach(1...10, id: \.self) { value in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(value == mood ? Color.moodGradient(for: value) : Color.white.opacity(0.1))
                            .frame(height: 6)
                    }
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Previews

#Preview("Medium - Not Logged", as: .systemMedium) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 7)
}

#Preview("Medium - Mood Logged", as: .systemMedium) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: 8, hasUserSubmitted: false, currentStreak: 5)
}

#Preview("Medium - Fully Submitted", as: .systemMedium) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: 9, hasUserSubmitted: true, currentStreak: 30)
}

#Preview("Medium - Zero Streak", as: .systemMedium) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 0)
}
