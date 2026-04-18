import SwiftUI
import WidgetKit

struct MoodComplicationView: View {
    let entry: MoodTimelineEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.hasEntry {
                VStack(spacing: 0) {
                    Text("\(entry.moodScore)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("/10")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
            }
        }
        .widgetAccentable()
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.hasEntry {
                Text("Mood: \(entry.moodScore)/10")
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(entry.streakDays)-day streak")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Odozi")
                    .font(.headline)
                Text("No check-in yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        Group {
            if entry.hasEntry {
                Text("Mood: \(entry.moodScore)/10 \u{1F525}\(entry.streakDays)")
            } else {
                Text("Odozi — Check in")
            }
        }
    }

    private var cornerView: some View {
        ZStack {
            if entry.hasEntry {
                Text("\(entry.moodScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            } else {
                Image(systemName: "brain.head.profile")
            }
        }
        .widgetAccentable()
    }
}
