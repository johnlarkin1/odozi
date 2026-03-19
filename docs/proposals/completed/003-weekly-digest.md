---
title: Weekly Digest Notifications
status: draft
date: 2026-03-14
tags: [notifications, engagement, retention, weekly-summary, background-tasks]
---

# 003 — Weekly Digest Notifications

## Summary

Deliver an automated weekly summary notification every Sunday evening (user-configurable) that surfaces key stats from the past seven days — days journaled, average mood with week-over-week trend, top emotion, current streak, steps, and sleep. The notification includes a rendered summary card image and action buttons that deep-link into the Insights tab or start a new journal entry.

## Motivation

Weekly digest notifications are one of the highest-leverage retention mechanisms for habit-tracking apps. Research from Nir Eyal's habit loop model and industry benchmarks consistently show:

- **Re-engagement**: Users who receive a personalized weekly summary are 2-3x more likely to open the app in the following week compared to generic reminders.
- **Progress awareness**: Showing week-over-week trends (e.g., "your mood is up 0.4 from last week") creates a sense of momentum that reinforces the journaling habit.
- **Low annoyance**: Unlike daily reminders, weekly digests feel like a "gift" rather than nagging — they deliver value (your stats) rather than just asking for action.
- **Completeness incentive**: Seeing "5/7 days journaled" naturally motivates users to aim for 7/7 the following week.

Odyssey already computes most of the underlying stats (mood trends, streaks, step counts) across `YearInReviewService`, `TrendCalculator`, and `InsightsViewModel`. This feature repackages that data into a timely, push-delivered format.

## Technical Approach

### 1. `WeeklyDigestService` — Stats Computation

A new service that fetches the current and previous week's `DailyEntry` records from SwiftData and computes the digest payload.

```swift
// Odyssey/Services/WeeklyDigestService.swift

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WeeklyDigest")

struct WeeklyDigestData: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let daysJournaled: Int          // count of entries where hasPromptData == true
    let totalDays: Int              // always 7
    let averageMood: Double         // mean of feeling (1-10)
    let previousWeekAverageMood: Double?  // nil if no prior week data
    let moodTrendDelta: Double?     // currentAvg - previousAvg
    let topEmotion: String?         // most frequent singleWordFeeling
    let currentStreak: Int          // consecutive days ending today
    let averageSleepQuality: Double // mean of sleepQuality (1-10)
    let totalSteps: Int             // sum of stepCount
    let totalDrinks: Int            // sum of drinks
    let averageSleepHours: Double?  // mean of sleepHours (HealthKit)
    let averageScreenTimeHours: Double? // mean of screenTimeSeconds / 3600
}

enum WeeklyDigestService {
    /// Computes digest data for the 7-day window ending on `endDate`.
    static func computeDigest(
        context: ModelContext,
        endDate: Date = Date()
    ) -> WeeklyDigestData {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: endDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: endOfDay),
              let prevWeekStart = calendar.date(byAdding: .day, value: -13, to: endOfDay),
              let prevWeekEnd = calendar.date(byAdding: .day, value: -7, to: endOfDay)
        else {
            return .empty(endDate: endDate)
        }

        // Fetch current week entries
        let currentPredicate = #Predicate<DailyEntry> {
            $0.date >= weekStart && $0.date <= endOfDay
        }
        let currentDescriptor = FetchDescriptor(
            predicate: currentPredicate,
            sortBy: [SortDescriptor(\.date)]
        )
        let currentEntries = (try? context.fetch(currentDescriptor)) ?? []

        // Fetch previous week entries
        let prevPredicate = #Predicate<DailyEntry> {
            $0.date >= prevWeekStart && $0.date <= prevWeekEnd
        }
        let prevDescriptor = FetchDescriptor(
            predicate: prevPredicate,
            sortBy: [SortDescriptor(\.date)]
        )
        let prevEntries = (try? context.fetch(prevDescriptor)) ?? []

        // Filter to user-submitted entries
        let submitted = currentEntries.filter { $0.hasPromptData }
        let prevSubmitted = prevEntries.filter { $0.hasPromptData }

        // Average mood
        let avgMood = submitted.isEmpty
            ? 0
            : Double(submitted.reduce(0) { $0 + $1.feeling }) / Double(submitted.count)
        let prevAvgMood: Double? = prevSubmitted.isEmpty
            ? nil
            : Double(prevSubmitted.reduce(0) { $0 + $1.feeling }) / Double(prevSubmitted.count)

        // Top emotion (most frequent singleWordFeeling)
        var emotionCounts: [String: Int] = [:]
        for entry in submitted where !entry.singleWordFeeling.isEmpty {
            let word = entry.singleWordFeeling.lowercased()
            emotionCounts[word, default: 0] += 1
        }
        let topEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key

        // Current streak (reuse existing extension)
        let allDescriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allEntries = (try? context.fetch(allDescriptor)) ?? []
        let currentStreak = DailyEntry.currentStreak(from: allEntries)

        // Sleep quality
        let avgSleep = submitted.isEmpty
            ? 0
            : Double(submitted.reduce(0) { $0 + $1.sleepQuality }) / Double(submitted.count)

        // Steps
        let totalSteps = currentEntries.compactMap(\.stepCount).reduce(0, +)

        // Drinks
        let totalDrinks = submitted.reduce(0) { $0 + $1.drinks }

        // HealthKit sleep hours
        let sleepValues = currentEntries.compactMap(\.sleepHours)
        let avgSleepHours: Double? = sleepValues.isEmpty
            ? nil
            : sleepValues.reduce(0, +) / Double(sleepValues.count)

        // Screen time
        let screenValues = currentEntries.compactMap(\.screenTimeSeconds)
        let avgScreenTimeHours: Double? = screenValues.isEmpty
            ? nil
            : (screenValues.reduce(0, +) / Double(screenValues.count)) / 3600.0

        return WeeklyDigestData(
            weekStartDate: weekStart,
            weekEndDate: endOfDay,
            daysJournaled: submitted.count,
            totalDays: 7,
            averageMood: avgMood,
            previousWeekAverageMood: prevAvgMood,
            moodTrendDelta: prevAvgMood.map { avgMood - $0 },
            topEmotion: topEmotion,
            currentStreak: currentStreak,
            averageSleepQuality: avgSleep,
            totalSteps: totalSteps,
            totalDrinks: totalDrinks,
            averageSleepHours: avgSleepHours,
            averageScreenTimeHours: avgScreenTimeHours
        )
    }
}

extension WeeklyDigestData {
    static func empty(endDate: Date) -> WeeklyDigestData {
        WeeklyDigestData(
            weekStartDate: endDate, weekEndDate: endDate,
            daysJournaled: 0, totalDays: 7, averageMood: 0,
            previousWeekAverageMood: nil, moodTrendDelta: nil,
            topEmotion: nil, currentStreak: 0, averageSleepQuality: 0,
            totalSteps: 0, totalDrinks: 0, averageSleepHours: nil,
            averageScreenTimeHours: nil
        )
    }
}
```

### 2. Notification Content & Scheduling

The notification uses `UNCalendarNotificationTrigger` with a weekly recurrence pattern. The text body summarizes key stats; an attached image provides a richer visual.

```swift
// Odyssey/Services/WeeklyDigestNotificationManager.swift

import UserNotifications
import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WeeklyDigestNotification")

enum WeeklyDigestNotificationManager {
    static let notificationID = "weekly-digest"
    static let categoryID = "WEEKLY_DIGEST"

    // MARK: - Notification Actions & Category

    static func registerCategory() {
        let openJournal = UNNotificationAction(
            identifier: "OPEN_JOURNAL",
            title: "Open Insights",
            options: [.foreground]
        )
        let startEntry = UNNotificationAction(
            identifier: "START_ENTRY",
            title: "Start Today's Entry",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [openJournal, startEntry],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling

    /// Schedules a weekly digest notification for a specific day and time.
    /// - Parameters:
    ///   - weekday: 1 = Sunday, 2 = Monday, ... 7 = Saturday
    ///   - hour: Hour in 24h format (default 18 = 6 PM)
    ///   - minute: Minute (default 0)
    static func schedule(weekday: Int = 1, hour: Int = 18, minute: Int = 0) {
        // Persist preferences
        UserDefaults.standard.set(true, forKey: "weeklyDigestEnabled")
        UserDefaults.standard.set(weekday, forKey: "weeklyDigestWeekday")
        UserDefaults.standard.set(hour, forKey: "weeklyDigestHour")
        UserDefaults.standard.set(minute, forKey: "weeklyDigestMinute")

        Task {
            let granted = await NotificationService.requestAuthorization()
            guard granted else {
                logger.warning("Notification permission not granted for weekly digest")
                return
            }

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [notificationID])

            // We schedule a recurring trigger; the content will be populated
            // by a Notification Service Extension or refreshed via background task.
            // For now, schedule with placeholder content — the background task
            // replaces this with fresh stats before delivery.
            let content = UNMutableNotificationContent()
            content.title = "Your Weekly Digest"
            content.body = "Tap to see how your week went."
            content.sound = .default
            content.categoryIdentifier = categoryID

            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: notificationID,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                logger.info("Scheduled weekly digest for weekday=\(weekday) at \(hour):\(minute)")
            } catch {
                logger.error("Failed to schedule weekly digest: \(error)")
            }
        }
    }

    /// Fires the digest immediately with computed stats (called from background task).
    @MainActor
    static func fireWithStats(context: ModelContext) async {
        let digest = WeeklyDigestService.computeDigest(context: context)

        guard digest.daysJournaled > 0 else {
            logger.info("Skipping weekly digest — no entries this week")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = formatDigestBody(digest)
        content.sound = .default
        content.categoryIdentifier = categoryID

        // Attach summary card image
        if let imageURL = await renderDigestCard(digest) {
            if let attachment = try? UNNotificationAttachment(
                identifier: "digest-card",
                url: imageURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
            ) {
                content.attachments = [attachment]
            }
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(notificationID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Fired weekly digest notification")
        } catch {
            logger.error("Failed to fire weekly digest: \(error)")
        }
    }

    // MARK: - Text Formatting

    private static func formatDigestBody(_ digest: WeeklyDigestData) -> String {
        var parts: [String] = []

        // Days journaled
        parts.append("This week you journaled \(digest.daysJournaled)/\(digest.totalDays) days.")

        // Mood with trend
        let moodStr = String(format: "%.1f", digest.averageMood)
        if let delta = digest.moodTrendDelta, let prevAvg = digest.previousWeekAverageMood {
            let direction = delta >= 0 ? "up" : "down"
            let prevStr = String(format: "%.1f", prevAvg)
            parts.append("Average mood: \(moodStr), \(direction) from \(prevStr) last week.")
        } else {
            parts.append("Average mood: \(moodStr).")
        }

        // Streak
        if digest.currentStreak > 1 {
            parts.append("\(digest.currentStreak)-day streak going!")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Reschedule

    static func rescheduleIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "weeklyDigestEnabled") else { return }
        let weekday = UserDefaults.standard.object(forKey: "weeklyDigestWeekday") as? Int ?? 1
        let hour = UserDefaults.standard.object(forKey: "weeklyDigestHour") as? Int ?? 18
        let minute = UserDefaults.standard.object(forKey: "weeklyDigestMinute") as? Int ?? 0
        schedule(weekday: weekday, hour: hour, minute: minute)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
        UserDefaults.standard.set(false, forKey: "weeklyDigestEnabled")
        logger.info("Cancelled weekly digest")
    }
}
```

### 3. Rich Notification Card via `ImageRenderer`

Generate a summary card image matching the app's dark-mode design tokens. This image is attached to the notification and visible when the user long-presses or expands it.

```swift
// Odyssey/Views/Notifications/WeeklyDigestCardView.swift

import SwiftUI

struct WeeklyDigestCardView: View {
    let digest: WeeklyDigestData

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.accentAmber)
                Text("Weekly Digest")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(weekRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().background(Color.white.opacity(0.1))

            // Stats grid
            HStack(spacing: 16) {
                statPill(
                    icon: "book.fill",
                    value: "\(digest.daysJournaled)/\(digest.totalDays)",
                    label: "Journaled",
                    color: .accentTeal
                )
                statPill(
                    icon: "face.smiling",
                    value: String(format: "%.1f", digest.averageMood),
                    label: "Avg Mood",
                    color: .accentAmber
                )
                statPill(
                    icon: "flame.fill",
                    value: "\(digest.currentStreak)",
                    label: "Streak",
                    color: .coralRed
                )
            }

            // Trend indicator
            if let delta = digest.moodTrendDelta {
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(delta >= 0 ? Color.successGreen : Color.coralRed)
                    Text(String(format: "%+.1f from last week", delta))
                        .font(.subheadline)
                        .foregroundStyle(delta >= 0 ? Color.successGreen : Color.coralRed)
                }
            }

            // Secondary stats
            HStack(spacing: 16) {
                if digest.totalSteps > 0 {
                    miniStat(icon: "figure.walk", value: formatSteps(digest.totalSteps), color: .successGreen)
                }
                if let sleep = digest.averageSleepHours {
                    miniStat(icon: "bed.double.fill", value: String(format: "%.1fh", sleep), color: .cosmicPurple)
                }
                if let topEmotion = digest.topEmotion {
                    miniStat(icon: "heart.fill", value: topEmotion.capitalized, color: .nebulaPink)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardSurface)
        )
        .frame(width: 360)
    }

    private var weekRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: digest.weekStartDate)
        let end = formatter.string(from: digest.weekEndDate)
        return "\(start) – \(end)"
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"
    }
}

// MARK: - ImageRenderer helper

@MainActor
func renderDigestCard(_ digest: WeeklyDigestData) async -> URL? {
    let view = WeeklyDigestCardView(digest: digest)
        .environment(\.colorScheme, .dark)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 3.0  // Retina quality

    guard let image = renderer.cgImage else { return nil }

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("weekly-digest-\(UUID().uuidString).png")

    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }

    return url
}
```

### 4. Background Task Integration

Hook into the existing `BGTaskScheduler` pattern in `OdysseyAppDelegate.swift`. Register a new weekly processing task that fires the digest notification with fresh data.

```swift
// New task identifier: "com.odyssey.weeklydigest"
// Add to Info.plist BGTaskSchedulerPermittedIdentifiers array

// In OdysseyAppDelegate.swift — additions to didFinishLaunchingWithOptions:

BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.odyssey.weeklydigest",
    using: nil
) { task in
    guard let processingTask = task as? BGProcessingTask else { return }
    self.handleWeeklyDigest(task: processingTask)
}
scheduleWeeklyDigestTask()

// New methods in AppDelegate:

private func handleWeeklyDigest(task: BGProcessingTask) {
    scheduleWeeklyDigestTask() // Re-schedule for next week

    let digestTask = Task {
        do {
            let container = try DataContainer.create()
            await WeeklyDigestNotificationManager.fireWithStats(
                context: container.mainContext
            )
            task.setTaskCompleted(success: true)
        } catch {
            logger.error("Weekly digest task failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        digestTask.cancel()
    }
}

private func scheduleWeeklyDigestTask() {
    guard UserDefaults.standard.bool(forKey: "weeklyDigestEnabled") else { return }

    let request = BGProcessingTaskRequest(identifier: "com.odyssey.weeklydigest")
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false

    let weekday = UserDefaults.standard.object(forKey: "weeklyDigestWeekday") as? Int ?? 1
    let hour = UserDefaults.standard.object(forKey: "weeklyDigestHour") as? Int ?? 18
    let minute = UserDefaults.standard.object(forKey: "weeklyDigestMinute") as? Int ?? 0

    let calendar = Calendar.current
    let now = Date()

    // Find next occurrence of the target weekday/time
    var components = DateComponents()
    components.weekday = weekday
    components.hour = hour
    components.minute = minute

    guard let target = calendar.nextDate(
        after: now,
        matching: components,
        matchingPolicy: .nextTime
    ) else { return }

    // Schedule 30 minutes before so stats are computed before the
    // UNCalendarNotificationTrigger fires the placeholder
    request.earliestBeginDate = calendar.date(
        byAdding: .minute, value: -30, to: target
    )

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        logger.error("Could not schedule weekly digest task: \(error)")
    }
}
```

### 5. Deep Linking from Notification Actions

Handle notification action taps to navigate the user to the correct screen.

```swift
// In OdysseyApp.swift or a UNUserNotificationCenterDelegate:

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    switch response.actionIdentifier {
    case "OPEN_JOURNAL":
        // Navigate to Insights tab
        NavigationState.shared.selectedTab = .insights
    case "START_ENTRY":
        // Navigate to Today tab and open guided prompt flow
        NavigationState.shared.selectedTab = .today
        NavigationState.shared.showGuidedPrompt = true
    case UNNotificationDefaultActionIdentifier:
        // Default tap — open Insights
        if response.notification.request.content.categoryIdentifier
            == WeeklyDigestNotificationManager.categoryID {
            NavigationState.shared.selectedTab = .insights
        }
    default:
        break
    }
}
```

## Stats Included in the Digest

| Stat | Source Field | Computation |
|------|-------------|-------------|
| Days journaled | `hasPromptData` | Count entries in week where `hasPromptData == true` |
| Average mood | `feeling` (Int, 1-10) | Mean of `feeling` for entries with `hasPromptData` |
| Mood trend | `feeling` | Current week avg minus previous week avg |
| Top emotion | `singleWordFeeling` | Most frequent non-empty `singleWordFeeling` (lowercased) |
| Current streak | `date` + `hasPromptData` | Reuse `DailyEntry.currentStreak(from:)` in `DailyEntry+Streak.swift` |
| Average sleep quality | `sleepQuality` (Int, 1-10) | Mean of `sleepQuality` for submitted entries |
| Total steps | `stepCount` (Int?) | Sum of non-nil `stepCount` across all week entries |
| Average sleep hours | `sleepHours` (Double?) | Mean of non-nil HealthKit sleep values |
| Average screen time | `screenTimeSeconds` (Double?) | Mean of non-nil values, converted to hours |
| Total drinks | `drinks` (Int) | Sum of `drinks` for submitted entries |

## Integration Points

### New Files

| File | Purpose |
|------|---------|
| `Odyssey/Services/WeeklyDigestService.swift` | Stats computation from SwiftData |
| `Odyssey/Services/WeeklyDigestNotificationManager.swift` | Notification scheduling, content, actions, category registration |
| `Odyssey/Views/Notifications/WeeklyDigestCardView.swift` | SwiftUI card for `ImageRenderer` attachment |
| `Odyssey/Views/Profile/WeeklyDigestSettingsView.swift` | Settings UI (toggle, day picker, time picker) |

### Modified Files

| File | Change |
|------|--------|
| `Odyssey/OdysseyAppDelegate.swift` | Register `com.odyssey.weeklydigest` BGProcessingTask; add handler + scheduler |
| `Odyssey/OdysseyApp.swift` | Register `UNNotificationCategory` at launch; set `UNUserNotificationCenterDelegate`; handle deep links |
| `Odyssey/Services/NotificationService.swift` | Add `WeeklyDigestNotificationManager.registerCategory()` call in authorization flow |
| `Odyssey.xcodeproj` (Info.plist) | Add `com.odyssey.weeklydigest` to `BGTaskSchedulerPermittedIdentifiers` |
| `Odyssey/Views/Profile/` | Add navigation link to `WeeklyDigestSettingsView` in profile/settings |

## Settings UI

A dedicated settings section within the Profile tab:

```swift
// Odyssey/Views/Profile/WeeklyDigestSettingsView.swift

struct WeeklyDigestSettingsView: View {
    @AppStorage("weeklyDigestEnabled") private var isEnabled = false
    @AppStorage("weeklyDigestWeekday") private var weekday = 1  // Sunday
    @AppStorage("weeklyDigestHour") private var hour = 18
    @AppStorage("weeklyDigestMinute") private var minute = 0

    private let weekdays = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Weekly Digest", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        if newValue {
                            WeeklyDigestNotificationManager.schedule(
                                weekday: weekday, hour: hour, minute: minute
                            )
                        } else {
                            WeeklyDigestNotificationManager.cancel()
                        }
                    }
            } footer: {
                Text("Receive a summary of your week's journaling stats.")
            }

            if isEnabled {
                Section("Delivery Time") {
                    Picker("Day", selection: $weekday) {
                        ForEach(weekdays, id: \.0) { day in
                            Text(day.1).tag(day.0)
                        }
                    }

                    DatePicker(
                        "Time",
                        selection: timeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
                .onChange(of: weekday) { _, _ in reschedule() }
                .onChange(of: hour) { _, _ in reschedule() }
                .onChange(of: minute) { _, _ in reschedule() }
            }
        }
        .navigationTitle("Weekly Digest")
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: hour, minute: minute)
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute], from: newDate
                )
                hour = components.hour ?? 18
                minute = components.minute ?? 0
            }
        )
    }

    private func reschedule() {
        WeeklyDigestNotificationManager.schedule(
            weekday: weekday, hour: hour, minute: minute
        )
    }
}
```

## Trade-offs & Constraints

### Background Execution Limits
- `BGProcessingTask` is not guaranteed to run at the exact requested time. iOS may defer it based on battery, usage patterns, and system load. The dual approach (BGProcessingTask to compute fresh stats + UNCalendarNotificationTrigger as a fallback with static content) ensures the user always gets *something*, even if the background task was skipped.
- The background task window is typically 30 seconds for `BGAppRefreshTask` and several minutes for `BGProcessingTask`. The digest computation is lightweight (two SwiftData queries + arithmetic), well within limits.

### Notification Permissions
- Weekly digests depend on notification authorization. If the user has denied permissions, the Settings UI should detect this via `UNUserNotificationCenter.current().notificationSettings()` and show a prompt to open Settings.
- The feature reuses the existing `NotificationService.requestAuthorization()` flow, which requests `.alert`, `.badge`, and `.sound`.

### Computation Cost
- Two `FetchDescriptor` queries (7-day windows) with date predicates are O(n) on the SwiftData store but bounded to ~14 entries max. This is negligible.
- `ImageRenderer` for the card is the most expensive operation but runs only once per week and takes <100ms on modern devices.

### Notification Attachment Size
- `UNNotificationAttachment` images must be under 10 MB. The rendered card at 3x scale is approximately 50-100 KB, well within limits.
- Attachments are copied by the system; the temporary file can be cleaned up after scheduling.

### Existing Notification Coexistence
- The daily journal reminder (`daily-journal-reminder`) and weekly digest (`weekly-digest`) use distinct identifiers and will not conflict.
- `registerCategory()` must be called alongside existing category registration to avoid overwriting. Use `setNotificationCategories` with the union of all categories.

## Open Questions

1. **Skip empty weeks?** If the user journaled 0 days, should we skip the notification entirely (current behavior) or send an encouraging "You missed this week — start fresh today" message?

2. **Notification Service Extension vs. Background Task?** A `UNNotificationServiceExtension` could modify notification content just before delivery, allowing the recurring `UNCalendarNotificationTrigger` to always show fresh data without a separate BGProcessingTask. However, Notification Service Extensions require a remote (push) notification trigger, which Odyssey does not currently use. Worth revisiting if push notifications are added later.

3. **Digest history?** Should we persist `WeeklyDigestData` to SwiftData so users can browse past weekly summaries in the app? This would enable a "Digest History" view in Insights.

4. **Shareable cards?** The `WeeklyDigestCardView` could double as a shareable image (similar to the Year-in-Review cards). Should we add a share button in the Insights tab that renders the current week's digest?

5. **Localization of day/time?** The weekday picker should respect the user's locale for first day of week. `Calendar.current` handles this, but the UI labels need localization.

6. **A/B testing default day/time?** Sunday 6 PM is a common default for weekly summaries, but should we experiment with Monday morning ("here's how last week went, start this week strong")?

## Next Steps

1. **Implement `WeeklyDigestService`** with unit tests verifying stat computation against known `DailyEntry` fixtures (similar to `DailyEntryComputedTests`).
2. **Build `WeeklyDigestCardView`** and preview it in Xcode with sample data; iterate on design with dark-mode tokens.
3. **Wire up `WeeklyDigestNotificationManager`** — scheduling, category registration, and `fireWithStats`.
4. **Integrate background task** in `OdysseyAppDelegate` — register identifier, add to Info.plist.
5. **Add Settings UI** in Profile tab with toggle and day/time picker.
6. **Implement deep linking** — add `UNUserNotificationCenterDelegate` handling for action identifiers.
7. **Test on device** — use `BGTaskScheduler` simulate command in Xcode (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.odyssey.weeklydigest"]`) to verify end-to-end flow.
8. **Consider digest history persistence** based on user feedback from TestFlight.
