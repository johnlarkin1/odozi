---
title: macOS Companion App — Roadmap & Next Steps
status: in-progress
date: 2026-03-19
tags: [macos, cross-platform, companion-app, catalyst]
---

# 005 — macOS Companion App

## Summary

Bring Odyssey to macOS as a native companion app that shares the core journaling, insights, and sync codebase with iOS. The macOS app focuses on what the Mac is good at — comfortable long-form writing, reviewing your journal history, and exploring insights on a larger screen — while leaving passive data collection (HealthKit, Screen Time, background location) to the iPhone.

## Motivation

Users who journal on their phone often want to:
- **Review and reflect** on entries from a bigger screen during focused work time
- **Write longer journal entries** with a real keyboard
- **Explore insights and trends** with the space a desktop provides
- **Keep their data in sync** without manual export/import

A macOS companion app makes Odyssey a true multi-device wellness platform. It doesn't need to replicate every iOS feature — it needs to be the best place to *write* and *review*.

## Current State (PR #85)

PR #85 (`claude/macos-journal-app-3eopb`) lands the foundation. Here's what shipped:

### What works today

| Feature | Status | Notes |
|---------|--------|-------|
| Core journaling (guided prompts) | ✅ | Step-by-step navigation (no swipe, uses transitions) |
| Journal browsing & search | ✅ | Calendar view, searchable entry list, detail view |
| Insights dashboard | ✅ | Mood trends, streaks, word cloud, color palette, correlations |
| Map visualization | ✅ | MapKit with mood-colored pins |
| Year-in-review | ✅ | All 10 cards render, shareable via `NSImage` |
| Achievements | ✅ | Full gallery, unlock tracking |
| Auth (Apple/Google/GitHub) | ✅ | Clerk SDK integration |
| Cloud sync | ✅ | Encrypted upload/download, foreground sync |
| CSV export | ✅ | Full data export |
| Dark mode | ✅ | Enforced app-wide |
| Lottie animations | ✅ | `NSViewRepresentable` bridge |
| Data persistence | ✅ | SwiftData with `~/Library/Application Support/Odyssey/` |

### What's excluded (by design)

| Feature | Reason |
|---------|--------|
| HealthKit (steps, sleep, distance) | Framework is iOS/watchOS-only |
| Screen Time / DeviceActivity | Framework is iOS-only |
| Background snapshot service | `BGTaskScheduler` is iOS-only |
| Auto-photo surfacing | `PHAsset` photo library queries are iOS-optimized |
| Widgets | WidgetKit on macOS is possible but not prioritized |
| Onboarding permissions flow | No HealthKit/ScreenTime/Location permissions to request |

### Architecture decisions already made

- **`PlatformColor` typealias** (`Odyssey/Extensions/PlatformColor.swift`) — `UIColor` on iOS, `NSColor` on macOS
- **`PlatformImage` typealias** (`Odyssey/Extensions/CrossPlatform.swift`) — `UIImage` on iOS, `NSImage` on macOS
- **`#if os(macOS)`** guards in 17 shared files for framework-specific code
- **`NavigationSplitView`** sidebar instead of `TabView` for macOS navigation
- **Separate storage path** — App Support on macOS vs App Group on iOS (sync bridges the gap)
- **No `AppDelegate`** on macOS — simpler lifecycle, foreground-only sync

## Roadmap

### Phase 1: Polish & Ship (Priority: High)

The current PR gets the app *running*. This phase makes it feel like a real Mac app.

#### 1.1 macOS-native UX refinements

**Keyboard shortcuts** — Mac users expect keyboard-driven navigation.

```swift
// OdysseyMacApp.swift or MacMainView.swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("New Entry") { /* trigger guided prompt */ }
            .keyboardShortcut("n", modifiers: .command)
    }
    CommandMenu("Navigation") {
        Button("Today")    { selectedSection = .today }
            .keyboardShortcut("1", modifiers: .command)
        Button("Journal")  { selectedSection = .journal }
            .keyboardShortcut("2", modifiers: .command)
        Button("Insights") { selectedSection = .insights }
            .keyboardShortcut("3", modifiers: .command)
        Button("Profile")  { selectedSection = .profile }
            .keyboardShortcut("4", modifiers: .command)
    }
}
```

**Menu bar integration:**
- `CommandMenu` for navigation, new entry, export
- Standard Edit menu for text editing in journal entries
- Help menu linking to support

**Window management:**
- Reasonable minimum window size constraints
- Remember window position/size across launches (`NSWindow` restoration)
- Consider a `Settings` scene for preferences (macOS convention vs in-app profile tab)

**Touch Bar support** (if targeting older MacBooks):
- Low priority, but `NSTouchBar` integration is lightweight

#### 1.2 Guided prompt flow polish

The iOS flow uses `TabView(.page)` with swipe gestures. The macOS version uses manual step transitions, which is correct, but needs refinement:

- **Progress indicator** — horizontal step dots or progress bar (more discoverable than on mobile)
- **Keyboard navigation** — Enter/Return to advance, Escape to skip, Tab between fields
- **Larger text fields** — take advantage of screen real estate for gratitude/win/tension/journal steps
- **Back button** — Cmd+[ or explicit back arrow (no swipe-back on Mac)

#### 1.3 Settings scene

macOS apps use `Settings` (Cmd+,) instead of an in-app profile tab:

```swift
// OdysseyMacApp.swift
Settings {
    MacSettingsView()
        .environment(authManager)
        .environment(syncService)
        .modelContainer(container)
}
```

This should include:
- Account management (sign in/out, delete account)
- Sync status & manual sync trigger
- Daily reminder configuration (notifications work on macOS)
- Data export (CSV)
- About / version info

The Profile tab in the sidebar could then become either a simpler "Account" section or be removed entirely in favor of `Settings`.

#### 1.4 Build verification & CI

- [ ] Confirm `make build-mac` passes in CI (GitHub Actions with macOS runner)
- [ ] Add `make test-mac` target for macOS-specific tests
- [ ] Ensure the scheme (`OdysseyMac.xcscheme`) is properly shared for CI
- [ ] Code signing configuration for distribution (Developer ID or Mac App Store)

**Files to modify:** `Makefile`, `.github/workflows/` (if CI exists), `Odyssey.xcodeproj/`

---

### Phase 2: Enhanced Mac Experience (Priority: Medium)

Features that make the Mac version *better* than just a port.

#### 2.1 Rich text journal editing

The Mac is a writing machine. The journal entry step could offer:
- Markdown preview (live or toggle)
- Larger, resizable text editor
- Word count display
- Auto-save drafts (so closing the window doesn't lose in-progress entries)

This stays iOS-compatible if the underlying model stores plain text — the rich editing is a view-layer enhancement.

#### 2.2 Multi-window support

macOS naturally supports multiple windows. Useful scenarios:
- Open a journal entry in its own window (for side-by-side comparison)
- Detach insights into a separate window while journaling
- `WindowGroup` with `openWindow` API (SwiftUI lifecycle)

```swift
// Support opening individual entries in separate windows
WindowGroup(for: DailyEntry.ID.self) { $entryID in
    if let entryID {
        EntryDetailWindow(entryID: entryID)
    }
}
```

#### 2.3 Drag & drop photo attachment

macOS users expect drag-and-drop. The journey photo strip should accept:
- Dragged images from Finder or other apps
- Dropped image files (JPEG, PNG, HEIC)
- Paste from clipboard (Cmd+V)

```swift
.onDrop(of: [.image], isTargeted: nil) { providers in
    // Handle dropped images
}
```

#### 2.4 Quick Entry from menu bar

A lightweight menu bar extra (`MenuBarExtra`) for quick mood logging:

```swift
MenuBarExtra("Odyssey", systemImage: "brain.head.profile") {
    QuickMoodView()
}
.menuBarExtraStyle(.window)
```

This lets users log mood without switching to the full app — similar to the iOS widget experience but more interactive.

#### 2.5 Spotlight & Shortcuts integration

- **Spotlight indexing** — index journal entries via `CSSearchableIndex` so users can search entries from Spotlight
- **Shortcuts app** — expose "Log Mood" and "Export CSV" as Shortcuts actions via `AppIntents`

#### 2.6 macOS notifications

`UNUserNotificationCenter` works on macOS. Enable:
- Daily reminder notifications (already implemented in `NotificationService`, just needs to be enabled on macOS)
- Weekly digest notifications
- Notification actions (mark as complete, snooze)

---

### Phase 3: Data Bridge (Priority: Medium-High)

The killer feature of a companion app is seamless data flow between devices.

#### 3.1 iCloud sync via existing cloud infrastructure

The app already has `SyncService` with encrypted cloud sync. The macOS and iOS apps just need to:
- Use the same Clerk account
- Sync on foreground (already implemented on both platforms)
- Handle merge conflicts gracefully (server timestamp wins — already implemented)

**What's needed:**
- Verify the sync service works correctly on macOS (same API endpoints, same encryption)
- Test round-trip: create entry on Mac → appears on iPhone, and vice versa
- Handle the case where the same day's entry is edited on both devices
- Sync status indicator in the macOS sidebar or toolbar

#### 3.2 Shared iCloud container (alternative/supplement)

If users don't want to create an account, a shared iCloud container could bridge data:

```swift
// DataContainer.swift — shared CloudKit container
let schema = Schema([DailyEntry.self])
let config = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.johnlarkin.Odyssey")
)
```

**Trade-offs:**
- Pro: No account required, Apple handles sync
- Con: SwiftData + CloudKit sync is still buggy in practice, conflict resolution is opaque
- Con: No encryption layer (Apple encrypts at rest, but data is readable by Apple)

**Recommendation:** Stick with the existing `SyncService` for now. It's battle-tested and encrypted.

#### 3.3 Handoff & Universal Clipboard

- **Handoff** — start a journal entry on iPhone, continue on Mac (and vice versa)
- Requires `NSUserActivity` registration on both platforms
- Low effort, high perceived value

```swift
// In GuidedPromptFlowView
.userActivity("com.johnlarkin.Odyssey.journaling") { activity in
    activity.title = "Continue Journaling"
    activity.isEligibleForHandoff = true
    activity.userInfo = ["date": Date().formatted(.iso8601)]
}
```

---

### Phase 4: Platform-Exclusive Features (Priority: Low)

Features that only make sense on macOS.

#### 4.1 Detailed analytics view

The larger screen enables richer data exploration:
- Side-by-side chart comparisons (mood vs sleep vs steps)
- Date range selection with click-drag on charts
- Exportable chart images (for sharing or printing)
- Correlation matrix heatmap (all metrics at once)

#### 4.2 Journal printing

macOS has native print support. Offer:
- Print a single entry (formatted nicely)
- Print a date range of entries (monthly journal)
- PDF export of formatted entries (beyond raw CSV)

#### 4.3 AppleScript / Automation support

Power users on macOS expect scriptability:
- Export entries via AppleScript
- Trigger mood logging from scripts
- Integrate with other journaling tools

Low priority but differentiating for power users.

#### 4.4 Touch Bar support

For MacBook Pro models with Touch Bar:
- Show mood scale during guided prompts
- Quick navigation between sections
- Low effort via `NSTouchBar` SwiftUI integration

---

## Technical Considerations

### Platform conditional strategy

The current approach of `#if os(macOS)` / `#if os(iOS)` in shared files works well for the current scope (~17 files with conditionals). As the macOS app grows, watch for:

- **Files with more than 3-4 conditional blocks** — consider extracting platform-specific views into separate files (e.g., `GuidedPromptFlowView_iOS.swift` and `GuidedPromptFlowView_macOS.swift` with a shared protocol)
- **View modifiers that differ by platform** — the `CrossPlatform.swift` shim approach is clean; keep extending it
- **Framework imports** — keep iOS-only framework imports behind `#if os(iOS)` to avoid accidental macOS build failures

### Missing platform guards (potential build issues)

These files use iOS-only APIs without `#if os(iOS)` guards and may cause issues if added to the macOS target:

| File | iOS-only API | Risk |
|------|-------------|------|
| `BackgroundSnapshotService.swift` | `BGTaskScheduler`, `CLLocationManager` background mode | Won't compile on macOS if included |
| `HealthKitService.swift` | `HKHealthStore`, `HKQuery` | Won't compile on macOS |
| `SnapshotScheduler.swift` | `BGAppRefreshTaskRequest`, `BGProcessingTaskRequest` | Won't compile on macOS |
| `OdysseyAppDelegate.swift` | `UIApplicationDelegate`, `BGTaskScheduler` | Won't compile on macOS |
| `PhotoLibraryService.swift` | `PHAsset`, `PHImageManager` | Won't compile on macOS without adaptation |
| `ScreenTimeDataExtractor.swift` | `DeviceActivityResults` | Won't compile on macOS |

These files are currently excluded from the OdysseyMac target in the Xcode project — this exclusion must be maintained.

### Testing strategy

| Layer | Approach |
|-------|----------|
| Shared model/service logic | Unit tests that run on both iOS and macOS schemes |
| macOS-specific views | Manual testing + UI tests on macOS simulator |
| Cross-platform sync | Integration tests creating entries on one platform, verifying on the other |
| Build verification | CI job running `make build-mac` on every PR |

### Distribution

| Channel | Considerations |
|---------|---------------|
| **Mac App Store** | Requires App Review, sandboxing (already configured), provisioning profile |
| **Developer ID (direct download)** | Notarization required, more flexibility, no App Store commission |
| **TestFlight for Mac** | Available for beta testing |

**Recommendation:** Start with TestFlight for beta, then Mac App Store for distribution alongside the iOS app (unified purchase or free companion).

## Open Questions

1. **Should the Profile tab become a Settings scene on macOS?** — macOS convention is Cmd+, for settings. Keeping Profile as a tab works but feels iOS-ported.

2. **Free companion or paid?** — If Odyssey iOS is free, the Mac app should be too. If there's a subscription, it should cover both platforms.

3. **Minimum macOS version?** — iOS 17+ maps to macOS 14 (Sonoma). This is reasonable as a floor.

4. **Should we support Mac Catalyst as an alternative?** — The current approach (native macOS target sharing source files) is better than Catalyst for UX quality, but Catalyst would be less maintenance. Given that PR #85 already established the native target approach, stick with it.

5. **Location capture on macOS?** — `CLLocationManager` works on macOS but requires location permission. Worth enabling for "where was I when I wrote this?" context, but not critical for v1.

6. **Menu bar app or full app?** — Could offer both: full app for browsing/insights, menu bar extra for quick mood logging. Phase 2 scope.

## Next Steps

Immediate (pre-merge of PR #85):
- [ ] Verify `make build-mac` compiles cleanly
- [ ] Manual smoke test: launch → create entry → view in journal → check insights
- [ ] Fix any remaining compilation warnings

Post-merge, Phase 1:
- [ ] Add keyboard shortcuts (Cmd+N, Cmd+1-4)
- [ ] Add `CommandMenu` for navigation
- [ ] Implement `Settings` scene (extract from Profile tab)
- [ ] Set up CI for macOS builds
- [ ] Polish guided prompt flow (larger text fields, keyboard nav)
- [ ] Test cloud sync round-trip between iOS and macOS

Phase 2:
- [ ] Menu bar extra for quick mood entry
- [ ] Drag-and-drop photo attachment
- [ ] Multi-window support for entry detail views
- [ ] macOS notifications (daily reminder, weekly digest)
- [ ] Rich text / markdown editing for journal entries

Phase 3:
- [ ] Handoff between iOS ↔ macOS
- [ ] Spotlight indexing of journal entries
- [ ] App Intents / Shortcuts integration
- [ ] TestFlight beta distribution
