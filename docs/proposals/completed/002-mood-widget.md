---
title: Mood Check-in Widget (WidgetKit)
status: draft
date: 2026-03-14
tags: [widgetkit, engagement, mood, home-screen, ios17]
---

# Mood Check-in Widget (WidgetKit)

## Summary

Add a WidgetKit-powered home screen widget that lets users log their mood with a single tap, without opening the app. Leveraging iOS 17+ interactive widgets (Button-based App Intents), the widget writes directly to the shared SwiftData store via the existing App Group. This reduces the friction of daily check-ins from "open app, navigate flow, select mood" to a one-tap action on the home screen or lock screen, significantly boosting daily engagement and streak retention.

## Motivation

### The engagement gap

Odyssey's guided prompt flow is comprehensive (9 steps), but that depth creates friction for the most critical daily data point: **mood**. Industry data shows that home screen widgets drive 2-3x the daily engagement of notification-only strategies because they keep the app visually present and actionable without requiring a launch.

### Why mood specifically

- **Mood (`feeling`, 1-10 scale)** is the single highest-value field in `DailyEntry` -- it feeds mood trend charts, the `moodGradient` color system, map pins, year-in-review sparklines, and streak calculations.
- A mood-only check-in still creates a valid `DailyEntry` (all other fields have sensible defaults), so it counts toward streaks.
- Users who log mood from the widget are primed to open the app and complete the full guided flow, creating a natural engagement funnel.

### Alignment with existing architecture

The app already uses App Groups (`group.com.johnlarkin.Odyssey`) for cross-process data sharing (Screen Time extension), and the SwiftData store is already located in the App Group container (`DataContainer.appGroupStoreURL`). This means the heaviest infrastructure work is already done.

## Technical Approach

### 1. Widget Extension Target Setup

Create a new target: **OdysseyWidget** (Widget Extension).

**Xcode configuration:**
- Deployment target: iOS 17.0
- App Group: `group.com.johnlarkin.Odyssey` (same as existing extensions)
- Include `DailyEntry.swift`, `DataContainer.swift`, `Color+Extensions.swift`, and `UserPreferences.swift` in the widget target (or extract into a shared framework -- see Trade-offs)

**Info.plist / entitlements:**
- `com.apple.security.application-groups`: `group.com.johnlarkin.Odyssey`
- No HealthKit or FamilyControls entitlements needed (widget only reads/writes mood)

### 2. Shared SwiftData Access

The widget extension runs in a separate process but can access the same SwiftData store through the App Group container. `DataContainer` already resolves the store URL from the App Group:

```swift
// DataContainer.swift (already exists -- no changes needed)
static var appGroupStoreURL: URL {
    if let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) {
        return container.appendingPathComponent("Odyssey.store")
    }
    // fallback...
}
```

The widget creates its own `ModelContainer` at launch:

```swift
// OdysseyWidget/WidgetDataAccess.swift (new file)
import SwiftData
import Foundation

enum WidgetDataAccess {
    static func makeContainer() throws -> ModelContainer {
        // Reuse DataContainer.create() -- the shared file is included in this target
        return try DataContainer.create()
    }

    static func fetchTodayEntry(context: ModelContext) -> DailyEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func recordMood(_ value: Int, context: ModelContext) throws {
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        let entry: DailyEntry
        if let existing = try context.fetch(descriptor).first {
            entry = existing
        } else {
            entry = DailyEntry(date: today)
            context.insert(entry)
        }

        entry.feeling = value
        entry.updatedAt = Date()
        // Note: we intentionally do NOT set hasUserSubmitted here.
        // The widget mood is a "quick check-in" -- the full guided flow
        // sets hasUserSubmitted when the user completes all prompts.
        try context.save()
    }
}
```

**Important concurrency note:** SwiftData uses SQLite under the hood with WAL mode. The main app and widget can both access the store, but we must handle the case where both write simultaneously. SwiftData's built-in SQLite locking handles this at the database level. To keep the main app's UI in sync, we use `WidgetCenter` notifications and the existing `scenePhase` catch-up logic (the app already re-fetches on `.active`).

### 3. Interactive Widget with App Intents

iOS 17 introduced interactive widgets via `Button` and `Toggle` views that execute `AppIntent` conformances directly in the widget extension process. No app launch required.

```swift
// OdysseyWidget/LogMoodIntent.swift (new file)
import AppIntents
import SwiftData
import WidgetKit

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var description: IntentDescription = "Records your mood for today"

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

        // Write to SharedDefaults so the main app can detect the change quickly
        SharedDefaults.suite.set(moodValue, forKey: SharedDefaultsKeys.widgetMoodValue)
        SharedDefaults.suite.set(
            Date().timeIntervalSince1970,
            forKey: SharedDefaultsKeys.widgetMoodTimestamp
        )

        // Force timeline reload so the widget updates immediately
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// Keys for widget <-> app communication via SharedDefaults
enum SharedDefaultsKeys {
    static let widgetMoodValue = "widgetMoodValue"
    static let widgetMoodTimestamp = "widgetMoodTimestamp"
}
```

### 4. Timeline Provider

The widget uses `TimelineProvider` to show today's mood status and refresh at midnight:

```swift
// OdysseyWidget/MoodWidgetProvider.swift (new file)
import WidgetKit
import SwiftData

struct MoodWidgetEntry: TimelineEntry {
    let date: Date
    let todayMood: Int?           // nil = not yet logged
    let hasUserSubmitted: Bool    // true = full guided flow completed
    let currentStreak: Int
}

struct MoodWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(date: .now, todayMood: 7, hasUserSubmitted: true, currentStreak: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodWidgetEntry>) -> Void) {
        let entry = makeEntry()

        // Refresh at midnight so the widget resets for the new day
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func makeEntry() -> MoodWidgetEntry {
        guard let container = try? WidgetDataAccess.makeContainer() else {
            return MoodWidgetEntry(date: .now, todayMood: nil, hasUserSubmitted: false, currentStreak: 0)
        }

        let context = ModelContext(container)
        let todayEntry = WidgetDataAccess.fetchTodayEntry(context: context)

        let streak = calculateStreak(context: context)

        return MoodWidgetEntry(
            date: .now,
            todayMood: todayEntry?.feeling,
            hasUserSubmitted: todayEntry?.hasUserSubmitted ?? false,
            currentStreak: streak
        )
    }

    private func calculateStreak(context: ModelContext) -> Int {
        // Simplified streak: count consecutive days with entries going backwards from yesterday
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        // If today has an entry, count it
        let todayPredicate = #Predicate<DailyEntry> { $0.date == checkDate }
        var todayDesc = FetchDescriptor(predicate: todayPredicate)
        todayDesc.fetchLimit = 1
        if (try? context.fetch(todayDesc).first) != nil {
            streak = 1
        }

        // Walk backwards
        while true {
            guard let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
            let prev = Calendar.current.startOfDay(for: prevDay)
            let predicate = #Predicate<DailyEntry> { $0.date == prev }
            var desc = FetchDescriptor(predicate: predicate)
            desc.fetchLimit = 1
            guard (try? context.fetch(desc).first) != nil else { break }
            streak += 1
            checkDate = prev
            if streak > 365 { break } // safety cap
        }

        return streak
    }
}
```

### 5. Widget UI Design

All widget sizes use Odyssey's dark aesthetic: `deepSpaceBlue` background, `accentAmber` accents, `moodGradient` colors, and `cardSurface` for interactive elements.

#### Small Widget (systemSmall) -- Quick 5-Point Mood Scale

The small widget presents 5 emoji-labeled mood buckets that map to the 1-10 scale. This is a deliberate simplification for the constrained widget size -- each bucket maps to a pair of values on the full scale.

```swift
// OdysseyWidget/SmallMoodWidgetView.swift (new file)
import SwiftUI
import WidgetKit
import AppIntents

struct SmallMoodWidgetView: View {
    let entry: MoodWidgetEntry

    // 5 buckets mapping to the 1-10 scale midpoints
    private let moodOptions: [(emoji: String, label: String, value: Int)] = [
        ("😣", "Awful", 2),
        ("😕", "Low", 4),
        ("😐", "Okay", 5),
        ("😊", "Good", 7),
        ("🤩", "Great", 9),
    ]

    var body: some View {
        VStack(spacing: 6) {
            if let mood = entry.todayMood, entry.hasUserSubmitted {
                // Already completed full flow -- show status
                Text("Today")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(mood)/10")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.moodGradient(for: mood))
                Text(moodLabel(for: mood))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.moodGradient(for: mood))
                if entry.currentStreak > 1 {
                    Label("\(entry.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.accentAmber)
                }
            } else {
                // Not yet logged -- show tappable mood buttons
                Text("How are you?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.starWhite)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                    ForEach(moodOptions, id: \.value) { option in
                        Button(intent: LogMoodIntent(moodValue: option.value)) {
                            VStack(spacing: 2) {
                                Text(option.emoji)
                                    .font(.system(size: 20))
                                Text(option.label)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.cardSurface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if entry.todayMood != nil {
                    // Mood logged via widget but full flow not done
                    Text("Tap to finish journal")
                        .font(.system(size: 8))
                        .foregroundStyle(.accentAmber)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.deepSpaceBlue
        }
        .widgetURL(URL(string: "odyssey://guided-prompt"))
    }

    private func moodLabel(for value: Int) -> String {
        switch value {
        case 1: return "Awful"
        case 2: return "Very Bad"
        case 3: return "Bad"
        case 4: return "Below Avg"
        case 5: return "Okay"
        case 6: return "Decent"
        case 7: return "Good"
        case 8: return "Great"
        case 9: return "Amazing"
        case 10: return "Best Ever"
        default: return "Okay"
        }
    }
}
```

#### Medium Widget (systemMedium) -- Full 1-10 Scale + Today's Status

The medium widget has room for the complete 1-10 mood bar (matching the in-app `MoodPromptCard` aesthetic) plus a status summary.

```swift
// OdysseyWidget/MediumMoodWidgetView.swift (new file)
import SwiftUI
import WidgetKit
import AppIntents

struct MediumMoodWidgetView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.accentAmber)
                    .font(.caption)
                Text("Odyssey")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.starWhite)
                Spacer()
                if entry.currentStreak > 1 {
                    Label("\(entry.currentStreak)", systemImage: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.accentAmber)
                }
            }

            if let mood = entry.todayMood, entry.hasUserSubmitted {
                // Completed state
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Mood")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(mood)/10")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.moodGradient(for: mood))
                    }
                    Spacer()
                    // Mini bar visualization
                    HStack(spacing: 3) {
                        ForEach(1...10, id: \.self) { value in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(value <= mood
                                    ? Color.moodGradient(for: value)
                                    : Color.white.opacity(0.15))
                                .frame(width: 12, height: 24)
                        }
                    }
                }
            } else {
                // Interactive mood bar
                Text("How are you feeling?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.starWhite)

                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { value in
                        Button(intent: LogMoodIntent(moodValue: value)) {
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        entry.todayMood == value
                                            ? Color.moodGradient(for: value)
                                            : (entry.todayMood != nil && value <= entry.todayMood!
                                                ? Color.moodGradient(for: value)
                                                : Color.white.opacity(0.15))
                                    )
                                    .frame(height: 28)
                                if value == 1 || value == 5 || value == 10 {
                                    Text(value == 1 ? "Low" : value == 5 ? "Mid" : "High")
                                        .font(.system(size: 7))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("Awful")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let mood = entry.todayMood {
                        Text("\(mood)/10 -- tap to open full journal")
                            .font(.system(size: 8))
                            .foregroundStyle(.accentAmber)
                    }
                    Spacer()
                    Text("Best Ever")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.deepSpaceBlue
        }
        .widgetURL(URL(string: "odyssey://guided-prompt"))
    }
}
```

#### Lock Screen Accessory Widget (accessoryCircular)

A minimal circular widget showing today's mood value or a prompt icon.

```swift
// OdysseyWidget/AccessoryMoodWidgetView.swift (new file)
import SwiftUI
import WidgetKit

struct AccessoryMoodWidgetView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        if let mood = entry.todayMood {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(mood)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("/10")
                        .font(.system(size: 8, weight: .medium))
                }
            }
            .widgetLabel("Mood")
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
            }
            .widgetLabel("Check in")
        }
    }
}
```

### 6. Widget Bundle Entry Point

```swift
// OdysseyWidget/OdysseyWidgetBundle.swift (new file)
import WidgetKit
import SwiftUI

@main
struct OdysseyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoodCheckInWidget()
    }
}

struct MoodCheckInWidget: Widget {
    let kind = "MoodCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodWidgetProvider()) { entry in
            MoodCheckInWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Check-in")
        .description("Log your mood with a single tap")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
        ])
        .contentMarginsDisabled()
    }
}

struct MoodCheckInWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoodWidgetEntry

    var body: some View {
        switch family {
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
```

### 7. Deep Link into Full Guided Flow

The widget uses `widgetURL` to deep-link into the app. When a user taps the widget background (not an interactive button), the app opens directly to the guided prompt flow.

**Changes needed in OdysseyApp.swift:**

```swift
// Add to OdysseyApp body, on the ContentView:
.onOpenURL { url in
    guard url.scheme == "odyssey" else { return }
    switch url.host {
    case "guided-prompt":
        // Post notification to trigger the guided prompt flow
        NotificationCenter.default.post(
            name: .openGuidedPrompt,
            object: nil
        )
    default:
        break
    }
}
```

And add the notification name:

```swift
extension Notification.Name {
    static let openGuidedPrompt = Notification.Name("openGuidedPrompt")
}
```

The `ContentView` (or `TodayView`) listens for this notification and presents the `GuidedPromptFlowView` as a full-screen cover.

### 8. Widget-to-App Sync

When the main app returns to foreground, the existing `foregroundCatchUp()` method in `OdysseyApp.swift` already re-reads the SwiftData store. No additional sync code is needed for the mood value itself since both the app and widget write to the same SQLite file.

However, to give the app a signal that the widget wrote data (useful for analytics or UI refresh), the `LogMoodIntent` also writes a timestamp to `SharedDefaults`. The app can check this on foreground:

```swift
// Add to foregroundCatchUp() in OdysseyApp.swift:
// Check if widget logged a mood
let widgetMoodTimestamp = SharedDefaults.suite.double(
    forKey: SharedDefaultsKeys.widgetMoodTimestamp
)
if widgetMoodTimestamp > 0 {
    let widgetDate = Date(timeIntervalSince1970: widgetMoodTimestamp)
    if Calendar.current.isDateInToday(widgetDate) {
        // Widget mood was logged today -- the SwiftData store already
        // has the value. Just ensure the UI refreshes.
        logger.info("Widget mood detected for today")
    }
}
```

## Widget Size Summary

| Family | Size | Interaction | Content |
|--------|------|-------------|---------|
| `systemSmall` | 2x2 grid | 5 tappable emoji buttons (maps to 1-10 scale) | Quick mood log, streak badge |
| `systemMedium` | 4x2 grid | 10 tappable bar segments (full 1-10 scale) | Mood bar matching in-app design, status + streak |
| `accessoryCircular` | Lock screen circle | Tap opens app (no interactive buttons on lock screen) | Mood value or prompt icon |

## Integration Points

### New Files to Create

| File | Target | Purpose |
|------|--------|---------|
| `OdysseyWidget/OdysseyWidgetBundle.swift` | OdysseyWidget | Widget entry point and configuration |
| `OdysseyWidget/MoodWidgetProvider.swift` | OdysseyWidget | Timeline provider |
| `OdysseyWidget/LogMoodIntent.swift` | OdysseyWidget | App Intent for interactive mood logging |
| `OdysseyWidget/WidgetDataAccess.swift` | OdysseyWidget | SwiftData container + fetch/write helpers |
| `OdysseyWidget/SmallMoodWidgetView.swift` | OdysseyWidget | Small widget UI |
| `OdysseyWidget/MediumMoodWidgetView.swift` | OdysseyWidget | Medium widget UI |
| `OdysseyWidget/AccessoryMoodWidgetView.swift` | OdysseyWidget | Lock screen widget UI |
| `OdysseyWidget/Info.plist` | OdysseyWidget | Extension plist |
| `OdysseyWidget/OdysseyWidget.entitlements` | OdysseyWidget | App Group entitlement |

### Existing Files to Modify

| File | Change |
|------|--------|
| `Odyssey.xcodeproj` | Add OdysseyWidget target, link to App Group, add shared source files |
| `Odyssey/OdysseyApp.swift` | Add `.onOpenURL` handler for `odyssey://guided-prompt` deep link |
| `Odyssey/Models/DailyEntry.swift` | No changes (already has all needed fields) |
| `Odyssey/Models/DataContainer.swift` | No changes (already uses App Group store URL) |
| `Odyssey/Services/SharedDefaults.swift` | Add `SharedDefaultsKeys` enum with widget mood keys |
| `Odyssey/Extensions/Color+Extensions.swift` | No changes (include in widget target as-is) |

### Files to Include in Widget Target (Multi-Target Membership)

These existing files need to be added to the OdysseyWidget target's Compile Sources:

- `Odyssey/Models/DailyEntry.swift`
- `Odyssey/Models/DataContainer.swift`
- `Odyssey/Models/UserPreferences.swift`
- `Odyssey/Extensions/Color+Extensions.swift`
- `Odyssey/Services/SharedDefaults.swift`

**Alternative:** Extract these into a shared framework (`OdysseyCore`) to avoid multi-target membership complexity. See Trade-offs below.

## Trade-offs & Constraints

### Widget process limitations

- **No background execution.** Widgets cannot run background tasks. The `TimelineProvider` runs briefly when the system requests a timeline, and `AppIntent.perform()` runs briefly when a button is tapped. Both must complete quickly.
- **No networking.** Widgets should not make network requests in `perform()`. The mood log is local-only; syncing happens when the main app foregrounds.
- **Memory budget.** Widget extensions have a ~30 MB memory limit. The SwiftData `ModelContainer` is lightweight, but we must avoid loading large datasets. The timeline provider only fetches 1-2 entries.
- **No @Observable.** Widgets use `TimelineEntry` structs, not `@Observable` view models. The widget view layer is stateless -- all data comes from the timeline entry.

### SwiftData concurrency

- Both the app and widget can write to the same SQLite store. SQLite's WAL mode handles concurrent access, but there is a small window where a write from one process may not be immediately visible to the other. This is acceptable because:
  - The widget reloads its timeline after writing (so it sees its own writes).
  - The app re-fetches on foreground (so it picks up widget writes within seconds).
- If a user logs mood via the widget and then immediately opens the app to the guided flow, the `GuidedPromptViewModel.loadExistingEntry()` method reads from SwiftData and will pick up the widget's mood value.

### Shared source files vs. shared framework

**Option A: Multi-target membership** (simpler, recommended for now)
Add existing source files to the widget target. Downside: any file-level changes (new imports, conditional compilation) must account for both targets.

**Option B: Extract `OdysseyCore` framework** (cleaner long-term)
Move `DailyEntry`, `DataContainer`, `UserPreferences`, `Color+Extensions`, and `SharedDefaults` into a shared framework. All four targets (app, two Device Activity extensions, widget) would link against it. Upside: single source of truth. Downside: more upfront refactoring.

**Recommendation:** Start with Option A for the initial implementation. If we add more extensions or shared logic, extract `OdysseyCore` in a follow-up.

### Widget interactivity constraints

- **`Button` and `Toggle` only.** iOS 17 interactive widgets support only these two controls -- no `TextField`, `Slider`, `Picker`, or custom gestures. This is why the mood selection uses discrete buttons rather than a slider.
- **No animation on interaction.** Widget views re-render after the intent completes, but there is no animated transition. The visual feedback is the timeline reload showing the updated state.
- **Lock screen widgets (`accessoryCircular`, `accessoryRectangular`, `accessoryInline`) do not support interactive controls.** They are tap-to-open only. This is why the accessory widget shows status rather than buttons.

### Mood scale mapping (small widget)

The small widget compresses the 1-10 scale to 5 options due to space constraints. The mapping:

| Widget Button | Emoji | Maps to `feeling` value |
|---------------|-------|------------------------|
| Awful | `😣` | 2 |
| Low | `😕` | 4 |
| Okay | `😐` | 5 |
| Good | `😊` | 7 |
| Great | `🤩` | 9 |

Users who want full granularity can use the medium widget or open the app.

## Open Questions

1. **Should widget mood set `hasUserSubmitted = true`?** Currently proposed as `false`, meaning the widget creates/updates an entry but it does not count as a "completed" journal. This encourages users to open the app and finish the full flow. However, if the goal is purely to maximize streak counts, we might want to set it to `true`. This is a product decision.

2. **Should we support `systemLarge` or `systemExtraLarge`?** A large widget could show a 7-day mood trend chart alongside today's check-in. This adds complexity (Swift Charts in widget, more data fetching) but could be a compelling v2 addition.

3. **`IntentConfiguration` vs `StaticConfiguration`?** The current proposal uses `StaticConfiguration` (no user-configurable parameters). An `IntentConfiguration` could let users choose which quick-prompt to show (mood vs. sleep vs. gratitude). Worth considering for v2.

4. **Analytics.** Should we track widget mood logs separately from in-app logs? This would help measure widget engagement impact. We could add a `source` field to `DailyEntry` (or a separate lightweight analytics event via SharedDefaults).

5. **Haptic feedback.** `AppIntent.perform()` can trigger haptics via `UINotificationFeedbackGenerator`, but widget extensions have limited access to UIKit. Need to verify this works reliably in the widget process.

6. **Should the medium widget show the current mood value after a widget tap (before full flow completion)?** The current design does this -- showing the bar filled to the selected value with a "tap to open full journal" hint. This creates a clear visual distinction between "quick mood logged" and "full journal completed."

## Next Steps

1. **Create the OdysseyWidget target** in Xcode with App Group entitlement
2. **Implement the core files:** `WidgetDataAccess`, `LogMoodIntent`, `MoodWidgetProvider`
3. **Build the three widget views** (small, medium, accessory circular)
4. **Add deep link handling** in `OdysseyApp.swift`
5. **Add `SharedDefaultsKeys`** to `SharedDefaults.swift`
6. **Test on physical device** -- verify SwiftData cross-process read/write, interactive button taps, timeline refresh
7. **Add widget preview providers** for Xcode canvas development
8. **Verify memory usage** stays under the 30 MB widget budget
9. **QA pass:** test edge cases (midnight rollover, no existing entry, app deleted and reinstalled, widget added before first app launch)
10. **Consider v2 enhancements:** large widget with trend chart, configurable prompts, Apple Watch complication
