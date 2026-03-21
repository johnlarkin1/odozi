import SwiftUI
import WidgetKit

@main
struct OdysseyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoodCheckInWidget()
    }
}

struct MoodCheckInWidget: Widget {
    let kind: String = "MoodCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodWidgetProvider()) { entry in
            MoodWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Check-In")
        .description("Log your mood with a single tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

private struct MoodWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: MoodWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallMoodWidgetView(entry: entry)
        case .systemMedium:
            MediumMoodWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryMoodWidgetView(entry: entry)
        default:
            SmallMoodWidgetView(entry: entry)
        }
    }
}
