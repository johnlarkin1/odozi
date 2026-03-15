import SwiftUI
import WidgetKit

struct AccessoryMoodWidgetView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let mood = entry.todayMood {
                VStack(spacing: 1) {
                    Text(emojiForMood(mood))
                        .font(.title3)
                    Text("\(mood)")
                        .font(.caption2.bold())
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "sun.max.fill")
                        .font(.title3)
                    Text("Log")
                        .font(.caption2.bold())
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "odyssey://guided-prompt"))
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

#Preview("Accessory - Not Logged", as: .accessoryCircular) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 0)
}

#Preview("Accessory - Logged", as: .accessoryCircular) {
    MoodCheckInWidget()
} timeline: {
    MoodWidgetEntry(date: .now, todayMood: 8, hasUserSubmitted: true, currentStreak: 5)
}
