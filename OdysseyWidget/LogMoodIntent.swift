import AppIntents
import SwiftData
import WidgetKit

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description: IntentDescription = "Log your mood for today"

    @Parameter(title: "Mood Value")
    var moodValue: Int

    init() {}

    init(moodValue: Int) {
        self.moodValue = moodValue
    }

    func perform() async throws -> some IntentResult {
        let container = try WidgetDataAccess.makeContainer()
        let context = ModelContext(container)
        try WidgetDataAccess.recordMood(moodValue, context: context)
        SharedDefaults.setWidgetMood(value: moodValue)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
