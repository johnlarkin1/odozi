---
title: Apple Watch Companion & macOS Desktop App
status: in-progress
date: 2026-03-19
tags: [watchos, macos, multi-platform, swiftui, healthkit, complications]
---

# 007 — Apple Watch Companion & macOS Desktop App

## Summary

Extend Odyssey to three Apple platforms — iOS (existing), macOS (in-progress via PR #85), and watchOS (new). The macOS app provides the full journal experience on desktop with sidebar navigation. The Apple Watch app provides a minimal, glanceable companion focused on quick mood check-ins, today's status, and HealthKit-sourced metrics — not the full journaling flow. All three platforms sync through the existing Clerk + Cloudflare Workers + Neon Postgres infrastructure, with SwiftData as the local persistence layer and the existing field-level merge strategy handling conflicts.

## Motivation

### macOS: Full Journal at Your Desk

- **Extended reflection sessions.** Users who journal daily often want to re-read, search, and reflect on past entries. A Mac app with a wide sidebar + detail layout is ideal for this.
- **Keyboard-friendly journaling.** Some users prefer typing long journal entries, gratitude, and tension responses on a full keyboard. macOS is a natural fit.
- **Ecosystem continuity.** Universal Purchase + Handoff means users can start an entry on their phone and finish it on their Mac (future: Handoff integration).

### watchOS: Quick Check-in on Your Wrist

- **Lowest-friction entry point.** A watch complication shows today's mood at a glance. Tapping it opens a 3-tap mood check-in — faster than pulling out a phone.
- **HealthKit at the source.** Apple Watch is the primary HealthKit data source for most users. Reading steps, sleep, and heart rate directly from the watch avoids the phone-as-middleman delay.
- **Notification response.** When the 8 PM "How are you feeling?" notification fires, users can respond directly on the watch with a mood score and single-word feeling.

### Why Not Just the Web Portal?

The web portal (Proposal 006) is view-only by design. Native clients are the entry points because they can:
- Capture passive data (HealthKit, location, Screen Time)
- Use native UI paradigms (Digital Crown, swipe gestures, haptics)
- Work offline (SwiftData local store)
- Receive and respond to push notifications

## Current State (PR #85 Review)

PR #85 introduces the `OdysseyMac` target with the following approach:

| Aspect | Implementation |
|--------|---------------|
| Code sharing | ~130 shared Swift source files between iOS and macOS |
| Platform conditionals | `#if os(macOS)` / `#if os(iOS)` compile-time branching |
| Navigation | `NavigationSplitView` (sidebar) replaces iOS `TabView` |
| Guided prompts | Step-by-step transitions + `sheet` instead of `fullScreenCover` + `TabView(.page)` |
| Platform shims | `PlatformColor.swift` (NSColor/UIColor), `CrossPlatform.swift` (toolbar placements, display mode) |
| Excluded features | HealthKit, Screen Time, BGTaskScheduler, widgets, photo library |
| Data storage | `~/Library/Application Support/Odyssey/` (no App Group on macOS) |
| Auth | Same Clerk integration, same API sync |

### PR #85 Issues to Address

1. **CI is failing** — lint check fails, build-and-test skipped
2. **No shared data store** — iOS uses App Group, macOS uses Application Support. Cloud sync is the only bridge
3. **`#if os()` proliferation** — 20+ conditionals scattered across shared files; needs protocol abstractions
4. **No macOS tests** — empty `<Testables>` in OdysseyMac.xcscheme
5. **Photo attachment missing** — `PhotosPicker` gated to iOS only; macOS users can't attach photos
6. **Toolbar placement inconsistencies** — mixed use of `.automatic` vs platform shims
7. **Lottie `contentMode` on macOS** — `NSView` doesn't have `contentMode` the same way `UIView` does

These should be resolved before merging PR #85. The rest of this proposal assumes they will be.

## Technical Approach: macOS

### Architecture

The macOS app shares the full SwiftUI view hierarchy with iOS, diverging only at navigation and platform-specific capabilities:

```
┌─ OdysseyMacApp (@main) ──────────────────────────────────┐
│                                                            │
│  ModelContainer (SwiftData)     Clerk Auth                 │
│  ~/Library/Application Support/ AuthManager.shared         │
│                                                            │
│  ┌─ MacMainView (NavigationSplitView) ──────────────────┐ │
│  │                                                        │ │
│  │  Sidebar          │  Detail                           │ │
│  │  ┌──────────┐    │  ┌──────────────────────────────┐ │ │
│  │  │ Today    │───▶│  │ TodayView (shared)           │ │ │
│  │  │ Journal  │    │  │ GuidedPromptFlowView (sheet) │ │ │
│  │  │ Insights │    │  │ JournalView (shared)         │ │ │
│  │  │ Profile  │    │  │ InsightsView (shared)        │ │ │
│  │  └──────────┘    │  │ ProfileView (shared)         │ │ │
│  │                   │  └──────────────────────────────┘ │ │
│  └───────────────────┴───────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### macOS-Specific Enhancements (Post PR #85)

#### 1. Keyboard Shortcuts

```swift
// Odyssey/Views/Shared/KeyboardShortcuts.swift
extension View {
    func odysseyKeyboardShortcuts() -> some View {
        self
            .keyboardShortcut("n", modifiers: .command)       // New entry
            .keyboardShortcut("f", modifiers: .command)       // Search journal
            .keyboardShortcut(",", modifiers: .command)       // Settings
            .keyboardShortcut("e", modifiers: .command)       // Export CSV
    }
}
```

#### 2. Menu Bar Extra (Status Item)

A persistent menu bar icon showing today's mood and streak:

```swift
// OdysseyMac/MenuBarExtra.swift
@main
struct OdysseyMacApp: App {
    var body: some Scene {
        WindowGroup {
            MacMainView()
        }

        #if os(macOS)
        MenuBarExtra("Odyssey", systemImage: "brain.head.profile") {
            VStack {
                Text("Today: 😊 8/10")
                Text("🔥 14-day streak")
                Divider()
                Button("Quick Check-in...") { /* open mini window */ }
                Button("Open Odyssey") { NSApp.activate() }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        #endif
    }
}
```

#### 3. Photo Attachment on macOS

Replace the iOS-only `PhotosPicker` with `NSOpenPanel` on macOS:

```swift
#if os(macOS)
Button("Add Photo") {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = true
    if panel.runModal() == .OK {
        for url in panel.urls {
            if let data = try? Data(contentsOf: url) {
                entry.attachedPhotoData?.append(data)
            }
        }
    }
}
#else
PhotosPicker(selection: $selectedPhotos) { /* ... */ }
#endif
```

#### 4. HealthKit on macOS

macOS 13+ supports HealthKit. The existing `HealthKitService` can be conditionally compiled:

```swift
// Odyssey/Services/HealthKitService.swift
#if canImport(HealthKit)
import HealthKit

class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // Existing implementation works on both platforms
    // Steps, walking distance, and sleep analysis are all available on macOS 13+
}
#endif
```

Note: Screen Time (FamilyControls/DeviceActivity) remains iOS-only. No macOS equivalent exists.

#### 5. Reduce `#if os()` with Protocol Abstractions

Extract platform-specific behavior into protocols to reduce scattered conditionals:

```swift
// Odyssey/Services/Platform/PlatformCapabilities.swift
protocol PlatformCapabilities {
    var supportsScreenTime: Bool { get }
    var supportsBackgroundTasks: Bool { get }
    var supportsWidgets: Bool { get }
    var supportsLocationBackground: Bool { get }
    var photoPickerAvailable: Bool { get }
    func requestPhotoAccess() async -> Bool
}

#if os(iOS)
struct iOSCapabilities: PlatformCapabilities {
    let supportsScreenTime = true
    let supportsBackgroundTasks = true
    let supportsWidgets = true
    let supportsLocationBackground = true
    let photoPickerAvailable = true
    func requestPhotoAccess() async -> Bool { /* PhotosUI */ }
}
#elseif os(macOS)
struct macOSCapabilities: PlatformCapabilities {
    let supportsScreenTime = false
    let supportsBackgroundTasks = false
    let supportsWidgets = true  // WidgetKit on macOS
    let supportsLocationBackground = false
    let photoPickerAvailable = false  // Use NSOpenPanel instead
    func requestPhotoAccess() async -> Bool { true } // No permission needed on macOS for file open
}
#endif
```

## Technical Approach: watchOS

### Architecture

The Apple Watch app is a **companion**, not a port. It surfaces a small subset of Odyssey's features optimized for the wrist:

```
┌─ OdysseyWatch (@main) ────────────────────────┐
│                                                 │
│  SwiftData (local)     WatchConnectivity        │
│                        (sync with iPhone)       │
│                                                 │
│  ┌─ Navigation ──────────────────────────────┐ │
│  │                                            │ │
│  │  Tab 1: Today Glance                      │ │
│  │  ├─ Mood orb (today's score)              │ │
│  │  ├─ Streak counter                        │ │
│  │  └─ "Check In" button                     │ │
│  │                                            │ │
│  │  Tab 2: Quick Check-In                    │ │
│  │  ├─ Mood slider (Digital Crown)           │ │
│  │  ├─ Feeling word picker (6 presets)       │ │
│  │  └─ Submit (haptic confirmation)          │ │
│  │                                            │ │
│  │  Tab 3: Week at a Glance                  │ │
│  │  ├─ 7-day mood bar chart                  │ │
│  │  └─ Steps + sleep summary                 │ │
│  │                                            │ │
│  └────────────────────────────────────────────┘ │
│                                                 │
│  Complications:                                 │
│  ├─ Circular: mood score number                │
│  ├─ Rectangular: mood + streak                 │
│  └─ Corner: mood emoji                         │
│                                                 │
└─────────────────────────────────────────────────┘
```

### watchOS Target Setup

#### New Xcode Target

```
odyssey-2/
├── Odyssey/                      # Shared source (iOS + macOS + watchOS)
├── OdysseyMac/                   # macOS-only entry point
├── OdysseyWatch/                 # watchOS-only entry point
│   ├── OdysseyWatchApp.swift     # @main
│   ├── TodayGlanceView.swift     # Tab 1
│   ├── QuickCheckInView.swift    # Tab 2 (mood + feeling)
│   ├── WeekSummaryView.swift     # Tab 3
│   ├── ComplicationProvider.swift # WidgetKit complications
│   └── Assets.xcassets           # Watch-specific assets
├── OdysseyWatch.entitlements     # HealthKit + App Group
└── ...
```

**watchOS minimum:** watchOS 10 (aligns with iOS 17 requirement; both require 2023+ hardware)

**Bundle ID:** `com.johnlarkin.Odyssey.watchkitapp`

**Entitlements:**
- HealthKit (steps, sleep, heart rate — directly from watch sensors)
- App Group: `group.com.johnlarkin.Odyssey` (shared with iOS for WatchConnectivity fallback)

#### Shared Files with watchOS

The watch target shares a subset of files:

| Shared | Not Shared (iOS/macOS only) |
|--------|-----------------------------|
| `DailyEntry.swift` | All views (too complex for watch) |
| `DataContainer.swift` | `GuidedPromptFlowView` and all prompt cards |
| `DailyEntryRepository.swift` | `InsightsView` and sub-views |
| `Achievement.swift` | `JournalView` and sub-views |
| `UserPreferences.swift` | `ProfileView` |
| `Color+Extensions.swift` | `BackgroundSnapshotService` |
| `SyncService.swift` | `LocationCaptureService` (use watch location instead) |
| `APIClient.swift` | Screen Time services |
| `EncryptionService.swift` | `OdysseyWidget/` |
| `AuthManager.swift` | Feature demos / UI tests |
| `HealthKitService.swift` | Photo services |

### Quick Check-In Flow

The watch check-in is a **3-screen flow** (not the full 8-step guided prompt):

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   How are you?      │     │   One word?          │     │       ✓             │
│                     │     │                      │     │                     │
│    ┌───────────┐    │     │   😊 Grateful        │     │   Mood: 8/10        │
│    │           │    │     │   😌 Calm             │     │   Feeling: Calm     │
│    │   8/10    │    │     │   😤 Stressed         │     │                     │
│    │           │    │     │   😢 Sad              │     │   Saved!            │
│    └───────────┘    │     │   🤩 Excited          │     │   🔥 15-day streak  │
│                     │     │   😐 Meh              │     │                     │
│  ◎ Turn Crown      │     │   ✏️ Custom...        │     │                     │
│                     │     │                      │     │                     │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
     Mood Score              Feeling Word                 Confirmation
    (Digital Crown)          (List or dictation)          (Haptic + dismiss)
```

```swift
// OdysseyWatch/QuickCheckInView.swift
import SwiftUI

struct QuickCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var moodScore: Double = 5
    @State private var step: CheckInStep = .mood
    @State private var selectedFeeling: String = ""

    enum CheckInStep { case mood, feeling, done }

    private let presetFeelings = ["Grateful", "Calm", "Stressed", "Sad", "Excited", "Meh"]

    var body: some View {
        switch step {
        case .mood:
            VStack {
                Text("How are you?")
                    .font(.headline)
                Text("\(Int(moodScore))/10")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(MoodColor.color(for: Int(moodScore)))
            }
            .focusable()
            .digitalCrownRotation($moodScore, from: 1, through: 10, by: 1,
                                   sensitivity: .medium, isContinuous: false,
                                   isHapticFeedbackEnabled: true)
            .onTapGesture { step = .feeling }

        case .feeling:
            List {
                ForEach(presetFeelings, id: \.self) { feeling in
                    Button(feeling) {
                        selectedFeeling = feeling
                        saveEntry()
                        step = .done
                    }
                }
                Button("Custom...") {
                    // Open dictation input
                }
            }
            .navigationTitle("One word?")

        case .done:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.successGreen)
                Text("Mood: \(Int(moodScore))/10")
                Text("Feeling: \(selectedFeeling)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                WKInterfaceDevice.current().play(.success)
            }
        }
    }

    private func saveEntry() {
        let repo = DailyEntryRepository(context: modelContext)
        let entry = try? repo.fetchOrCreateToday()
        entry?.feeling = Int(moodScore)
        entry?.singleWordFeeling = selectedFeeling.lowercased()
        entry?.feelingColorHex = MoodColor.hex(for: Int(moodScore))
        entry?.needsSync = true
        entry?.updatedAt = Date()
        try? modelContext.save()
    }
}
```

### HealthKit on Watch

The Apple Watch is the richest HealthKit data source. The existing `HealthKitService` works on watchOS with minor adjustments:

```swift
// Shared HealthKitService additions for watchOS
#if os(watchOS)
extension HealthKitService {
    /// Fetch heart rate samples for today
    func fetchHeartRate() async throws -> Double? {
        let heartRateType = HKQuantityType(.heartRate)
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: today, end: Date(), options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let bpm = result?.averageQuantity()?.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }
}
#endif
```

**Data captured on watch:**
- Steps (directly from accelerometer)
- Walking distance
- Sleep analysis (most accurate from watch worn overnight)
- Heart rate (watch-exclusive in many cases)
- Active calories (future enhancement)

### Complications (WidgetKit)

watchOS complications use WidgetKit (same framework as iOS widgets). The existing `OdysseyWidget` target architecture can be extended:

```swift
// OdysseyWatch/ComplicationProvider.swift
import WidgetKit
import SwiftUI

struct MoodComplication: Widget {
    let kind = "MoodComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodTimelineProvider()) { entry in
            MoodComplicationView(entry: entry)
        }
        .configurationDisplayName("Today's Mood")
        .description("Shows your current mood score")
        .supportedFamilies([
            .accessoryCircular,      // Small circle: mood number
            .accessoryRectangular,   // Wide rect: mood + streak
            .accessoryCorner,        // Corner: mood color arc
            .accessoryInline,        // Single line: "Mood: 8 · 🔥14"
        ])
    }
}

struct MoodComplicationView: View {
    let entry: MoodTimelineEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.moodScore)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("/10")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .widgetAccentable()

        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Mood: \(entry.moodScore)/10")
                    .font(.headline)
                HStack {
                    Image(systemName: "flame.fill")
                    Text("\(entry.streakDays)-day streak")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

        case .accessoryInline:
            Text("Mood: \(entry.moodScore) · 🔥\(entry.streakDays)")

        default:
            Text("\(entry.moodScore)")
        }
    }
}
```

### Data Sync Strategy

#### Option A: Cloud Sync Only (Recommended)

Each device syncs independently to the Cloudflare Workers API:

```
iPhone ──sync──▶ ┌──────────────┐ ◀──sync── Apple Watch
                 │  Neon Postgres │
macOS  ──sync──▶ │  (via Workers) │ ◀──read── Web Portal
                 └──────────────┘
```

- All devices use the same Clerk user ID
- Entries uploaded via `POST /entries` (batch upsert)
- Entries downloaded via `GET /entries?since=<lastSync>`
- Field-level merge in `SyncService.swift` resolves conflicts (already implemented)
- Watch entries contain fewer fields (no location, no screen time, no journal text) — merge strategy already handles partial entries

**Pros:** Simple, works on all platforms, no device-to-device pairing needed.
**Cons:** Requires internet; watch must have Wi-Fi/cellular or paired iPhone.

#### Option B: WatchConnectivity + Cloud Sync (Enhanced)

Add `WatchConnectivity` for real-time iPhone ↔ Watch sync when paired:

```swift
// Shared/Services/WatchSyncService.swift
import WatchConnectivity

class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // iPhone → Watch: send today's full entry after guided prompt completion
    func sendEntryToWatch(_ entry: DailyEntry) {
        guard WCSession.default.isReachable else { return }
        let payload: [String: Any] = [
            "date": entry.date.timeIntervalSince1970,
            "feeling": entry.feeling,
            "singleWordFeeling": entry.singleWordFeeling,
            "feelingColorHex": entry.feelingColorHex,
            "streakDays": calculateCurrentStreak(),
            // Only send what the watch needs to display
        ]
        WCSession.default.sendMessage(payload, replyHandler: nil)
    }

    // Watch → iPhone: send quick check-in data for iPhone to enrich
    func sendCheckInToPhone(mood: Int, feeling: String) {
        let payload: [String: Any] = [
            "type": "quickCheckIn",
            "mood": mood,
            "feeling": feeling,
            "timestamp": Date().timeIntervalSince1970,
        ]
        WCSession.default.transferUserInfo(payload) // Guaranteed delivery
    }
}
```

**Pros:** Instant sync, works without internet (via Bluetooth), better UX.
**Cons:** More complex, only works iPhone ↔ Watch (not macOS ↔ Watch).

**Recommendation:** Start with Option A (cloud-only). Add WatchConnectivity in a follow-up if latency is a problem.

### Notification Handling on Watch

The existing 8 PM notification should be actionable on watch:

```swift
// OdysseyWatch/NotificationHandler.swift
import UserNotifications

class WatchNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case "QUICK_CHECKIN":
            // Navigate to QuickCheckInView
            NavigationState.shared.showQuickCheckIn = true
        case "SNOOZE":
            // Reschedule for 1 hour later
            scheduleSnoozeNotification()
        default:
            break
        }
    }
}
```

Notification categories (register on both iOS and watchOS):

```swift
let checkInAction = UNNotificationAction(
    identifier: "QUICK_CHECKIN",
    title: "Check In",
    options: .foreground
)
let snoozeAction = UNNotificationAction(
    identifier: "SNOOZE",
    title: "Snooze 1hr",
    options: []
)
let category = UNNotificationCategory(
    identifier: "DAILY_CHECKIN",
    actions: [checkInAction, snoozeAction],
    intentIdentifiers: []
)
```

## Integration Points

### Shared Code (All Platforms)

| File | iOS | macOS | watchOS | Notes |
|------|-----|-------|---------|-------|
| `DailyEntry.swift` | ✅ | ✅ | ✅ | Core data model |
| `DataContainer.swift` | ✅ | ✅ | ✅ | Platform-specific store paths |
| `DailyEntryRepository.swift` | ✅ | ✅ | ✅ | CRUD operations |
| `SyncService.swift` | ✅ | ✅ | ✅ | Cloud sync |
| `APIClient.swift` | ✅ | ✅ | ✅ | Network layer |
| `EncryptionService.swift` | ✅ | ✅ | ✅ | AES-256-GCM |
| `AuthManager.swift` | ✅ | ✅ | ✅ | Clerk auth |
| `HealthKitService.swift` | ✅ | ✅ | ✅ | Health data |
| `Color+Extensions.swift` | ✅ | ✅ | ✅ | Design tokens |
| `Achievement.swift` | ✅ | ✅ | ❌ | Too complex for watch |
| `UserPreferences.swift` | ✅ | ✅ | ✅ | Notification prefs |

### Platform-Specific Code

| Feature | iOS | macOS | watchOS |
|---------|-----|-------|---------|
| Guided prompts (8 steps) | ✅ fullScreenCover | ✅ sheet | ❌ Quick check-in only |
| Screen Time capture | ✅ DeviceActivity | ❌ | ❌ |
| Background tasks | ✅ BGTaskScheduler | ❌ | ✅ WKApplicationRefreshBackgroundTask |
| Location capture | ✅ CLLocationManager | ✅ CLLocationManager | ✅ CLLocationManager (limited) |
| Widgets | ✅ WidgetKit | ✅ WidgetKit | ✅ Complications (WidgetKit) |
| Photo attachment | ✅ PhotosPicker | ✅ NSOpenPanel | ❌ |
| Map visualization | ✅ MapKit | ✅ MapKit | ❌ |
| Word cloud | ✅ FlowLayout | ✅ FlowLayout | ❌ |
| Year-in-review | ✅ ScrollView | ✅ ScrollView | ❌ |
| Menu bar | ❌ | ✅ MenuBarExtra | ❌ |
| Digital Crown | ❌ | ❌ | ✅ Mood input |
| Haptic feedback | ✅ UIFeedbackGenerator | ❌ | ✅ WKInterfaceDevice |

### Existing Files Modified

| File | Change |
|------|--------|
| `Odyssey.xcodeproj/project.pbxproj` | Add OdysseyWatch target, shared file references |
| `Odyssey/Models/DataContainer.swift` | Add `#if os(watchOS)` storage path |
| `Odyssey/Services/HealthKitService.swift` | Add watchOS heart rate, conditional imports |
| `Odyssey/Services/Sync/SyncService.swift` | No changes needed (already platform-agnostic) |
| `Odyssey/Extensions/Color+Extensions.swift` | Verify all colors work on watchOS |

## Trade-offs & Constraints

### macOS

| Advantage | Constraint |
|-----------|------------|
| Full journal experience on desktop | No Screen Time data (API doesn't exist on macOS) |
| Keyboard-friendly text entry | No background tasks (BGTaskScheduler is iOS-only; use `NSBackgroundActivityScheduler` instead) |
| Large screen for insights/charts | Separate data store (no App Group across iOS/macOS; cloud sync is the bridge) |
| HealthKit available on macOS 13+ | Limited health data (no direct sensor access like watch) |
| Menu bar quick access | Need to maintain `#if os()` conditionals or protocol abstractions |

### watchOS

| Advantage | Constraint |
|-----------|------------|
| Lowest-friction mood entry | Tiny screen — only mood + feeling word, no free-text journal |
| Best HealthKit data source | Limited storage (keep SwiftData lean, sync frequently) |
| Complications keep mood visible | watchOS background runtime is heavily restricted |
| Haptic feedback for confirmation | No camera, no photo attachment |
| Notification response on wrist | Watch apps must handle "no iPhone nearby" gracefully |
| Digital Crown for mood slider | Dictation for custom feeling words may have accuracy issues |

### Cross-Platform Sync Concerns

| Concern | Mitigation |
|---------|------------|
| Conflict when same entry edited on two devices | Existing field-level merge handles this; "prefer non-empty, prefer longer, timestamp breaks tie" |
| Watch creates partial entry, iPhone enriches it | Merge treats each field independently — watch sets mood + feeling, iPhone adds journal + location |
| Encryption key management across devices | Key stored in Keychain per-device. Clerk auth is the identity bridge; key-backup API enables cross-device key sharing |
| Network unavailable on watch | SwiftData persists locally; `needsSync = true` flag queues entries for upload when connectivity returns |

## Phased Rollout

### Phase 1: macOS Polish (2-3 weeks)
- Resolve PR #85 issues (CI, tests, toolbar, photos)
- Add macOS keyboard shortcuts
- Add menu bar extra with today's mood
- Enable HealthKit on macOS (steps, sleep — no watch-specific data)
- Write macOS UI tests

### Phase 2: watchOS MVP (3-4 weeks)
- Create `OdysseyWatch` target with SwiftData + shared models
- Build quick check-in flow (mood Digital Crown + feeling picker)
- Build today glance view (mood orb + streak)
- Implement mood complications (circular, rectangular, inline)
- Wire up cloud sync (reuse existing `SyncService`)
- Handle 8 PM notification with check-in action

### Phase 3: watchOS HealthKit (1-2 weeks)
- Read steps, sleep, heart rate directly on watch
- Auto-populate today's entry with watch health data
- Background refresh task to capture data periodically

### Phase 4: WatchConnectivity (1-2 weeks, optional)
- Real-time sync between iPhone and Watch
- Watch receives full entry data after iPhone guided prompt
- iPhone receives quick check-in data from watch

### Phase 5: macOS + watchOS Widgets (1-2 weeks)
- macOS desktop widget (mood trend, streak)
- watchOS complications v2 (week summary, mood trend sparkline)
- Shared WidgetKit timeline provider across iOS/macOS/watchOS

## Open Questions

1. **watchOS minimum version.** watchOS 10 aligns with iOS 17, but watchOS 11 adds new SwiftUI features (custom container views, mesh gradients). Target 10 or 11?

2. **Watch auth flow.** Clerk doesn't have a watchOS SDK. Options: (a) transfer auth token from iPhone via WatchConnectivity, (b) sign in on watch via companion app redirect, (c) use Apple's built-in account sync. Recommendation: (a) for paired watches, (c) as fallback.

3. **Watch storage limits.** watchOS apps have limited storage. Should we keep only the last 30 days of entries on watch and rely on cloud for history? Or sync everything?

4. **macOS App Store vs direct distribution.** Universal Purchase requires App Store for both iOS and macOS. Direct distribution (notarized DMG) is simpler but breaks Universal Purchase. Recommendation: App Store for both.

5. **Catalyst vs native macOS.** PR #85 chose native macOS (separate target, shared sources). Should we reconsider Catalyst for less maintenance overhead? Catalyst has improved in macOS 14+ but still has UI compromises. Recommendation: stay native, the `NavigationSplitView` approach is cleaner.

6. **Watch journal text.** Should the watch allow free-text journal entry via dictation? It's technically possible but the UX is poor for long-form writing. Recommendation: no — keep the watch focused on quick check-in (mood + feeling word only). Users can add journal text on iPhone/Mac later; merge handles this gracefully.

7. **Heart rate as mood proxy.** Should we surface heart rate variability on the watch as a "stress indicator" alongside self-reported mood? This is a compelling feature but raises questions about accuracy and user anxiety. Worth a separate proposal.

## Progress

### watchOS Implementation (branch: `feat-explore-apple-watch-support`)

- [x] **Phase 1: Skeleton App** — `OdysseyWatch/` directory with `@main` entry point, 3-tab TabView (Today Glance, Quick Check-In, Week Summary), `DataContainer.swift` updated with `#if os(watchOS)` schema (excludes Achievement), watchOS storage path, `build-watch` Makefile target
- [x] **Phase 2: Quick Check-In Flow** — `MoodCrownView` (Digital Crown 1-10 with haptics), `FeelingPickerView` (6 presets + custom), `CheckInConfirmationView` (haptic + auto-dismiss), saves to SwiftData with `needsSync = true`
- [x] **Phase 3: Auth + Cloud Sync** — `WatchAuthManager` (token-only, no Clerk SDK), `WatchSyncService` (upload/download via APIClient + EncryptionService), `WatchSessionReceiver` (WCSession delegate), `WatchConnectivityService` (iOS-side token transfer via `transferUserInfo`), `AuthManager` sends token to watch on refresh
- [x] **Phase 4: HealthKit on Watch** — `HealthKitService` extended with `fetchAverageHeartRate(for:)` under `#if os(watchOS)`, heart rate added to read types, `WatchHealthCapture` orchestrates concurrent HealthKit → DailyEntry population
- [x] **Phase 5: Complications** — `MoodComplication` widget with `MoodTimelineProvider`, views for `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`, `.accessoryCorner`, midnight refresh policy
- [ ] **Phase 6 (Future):** Notifications, week summary charts, bidirectional WatchConnectivity sync, background refresh

### Deviations from Original Design

- `SyncService.swift` is NOT shared with watchOS (depends on `AuthManager` which imports ClerkKit). Instead, `WatchSyncService` reimplements sync using `APIClient` + `EncryptionService` directly.
- `Achievement.swift` excluded from watchOS schema as planned.
- `PlatformColor.swift` updated with explicit `#elseif os(watchOS)` case.

### Manual Step Required

The `OdysseyWatch` Xcode target must be created manually in Xcode:
1. File > New > Target > watchOS > App
2. Product Name: `OdysseyWatch`, Bundle ID: `com.johnlarkin.Odyssey.watchkitapp`
3. Watch app for: `Odyssey` (companion), SwiftUI, watchOS 10.0 minimum
4. Add shared files to target membership (see shared file list in Phase 1 plan)
5. Add all `OdysseyWatch/*.swift` files to the new target

## Next Steps

1. **Merge PR #85** after resolving CI, tests, and photo attachment issues
2. **Create `OdysseyWatch` Xcode target** with shared model files
3. **Build quick check-in flow** with Digital Crown mood input
4. **Implement mood complications** using WidgetKit
5. **Test cloud sync** from watch → API → iPhone (verify field-level merge works with partial entries)
6. **Resolve watch auth** — prototype WatchConnectivity token transfer
7. **Add macOS keyboard shortcuts** and menu bar extra
8. **Write platform-specific tests** for both macOS and watchOS
