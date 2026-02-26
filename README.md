# Odyssey

A personal mental wellness tracking app for iOS, built with SwiftUI and SwiftData. Odyssey combines a guided daily journaling flow with passive background data capture to surface meaningful insights about your wellbeing over time.

## Features

**Guided Daily Journal**
- 8-step prompted flow: Mood, Feeling Color, Sleep, Gratitude, Win, Tension, Free Journal, Drinks
- Every step is skippable — low friction to encourage consistency
- Animated completion card on submit

**Passive Data Capture**
- GPS location with reverse geocoding (neighborhood/city)
- HealthKit integration (steps, walking distance, sleep analysis)
- Screen Time via DeviceActivityMonitor extensions
- Background task scheduling (8 PM snapshot + 2 AM fallback) with foreground catch-up

**Visualizations & Insights**
- Mood trend charts (Swift Charts)
- Map view with color-coded mood pins (MapKit)
- Streak tracking
- Word cloud from journal entries
- Feeling color palette over time
- Calendar heatmap

**Year in Review**
- Spotify Wrapped-style review with animated cards
- Shareable via `ImageRenderer`
- Lottie-powered Earth animation on the title card

## Requirements

- iOS 17+
- Xcode 16+
- Physical device required for Screen Time / FamilyControls features

## Getting Started

```bash
# Resolve Swift package dependencies
make resolve

# Build (simulator — Screen Time extensions will be skipped)
make build

# Build and run on simulator
make run

# Run tests
make test

# See all available commands
make help
```

To build without code signing (CI):

```bash
xcodebuild -project Odyssey.xcodeproj -target Odyssey -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

## Architecture

**Pattern:** MVVM with `@Observable` (iOS 17+)

### Targets

| Target | Purpose |
|--------|---------|
| `Odyssey` | Main app |
| `OdysseyDeviceActivityMonitor` | Out-of-process extension that monitors device activity |
| `OdysseyDeviceActivityReport` | ExtensionKit extension rendering Screen Time reports |
| `OdysseyTests` / `OdysseyUITests` | Test targets |

### Project Structure

```
Odyssey/
├── Models/              # SwiftData models (DailyEntry) and persistence (DataContainer)
├── ViewModels/          # @Observable view models
├── Views/
│   ├── Today/           # Home tab — greeting, entry status, journal launch
│   ├── GuidedPrompts/   # 8-step prompted journal flow + prompt cards
│   ├── Journal/         # Calendar view, searchable entry list, detail view
│   ├── Insights/        # Dashboard: mood trends, map, streaks, word cloud, heatmap
│   ├── YearInReview/    # Wrapped-style review cards
│   └── Profile/         # Screen Time report, app selection, CSV export
├── Services/            # Background tasks, HealthKit, location, shared defaults
└── Extensions/          # Color tokens, UIColor hex conversion
```

### Data Flow

1. `OdysseyApp` requests permissions (location, Screen Time, HealthKit) at launch
2. `AppDelegate` registers background tasks (`com.odyssey.snapshot` at 8 PM, `com.odyssey.processing` at 2 AM)
3. `BackgroundSnapshotService` captures location + HealthKit data concurrently via `async let`
4. Screen Time data flows from the report extension through shared `UserDefaults` (App Group)
5. On every `.active` scene phase, the app checks for and fills in any missing daily snapshot

### Dependencies

- [Lottie](https://github.com/airbnb/lottie-ios) (~> 4.0) — animated illustrations in Year in Review

## License

Private project — all rights reserved.
