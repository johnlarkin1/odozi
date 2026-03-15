# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Odyssey is an iOS mental wellness tracking app built with SwiftUI. It features a guided step-by-step daily journaling flow, passive background data capture (GPS + reverse geocoding, HealthKit, Screen Time), rich visualizations (mood trends, maps, streaks, word clouds), and a Spotify Wrapped-style year-in-review feature with shareable cards. Uses SwiftData for persistence and targets iOS 17+.

**Contact & Branding:**
- Contact email: john@odozi.app (use this everywhere, NOT john@johnjlarkin.com)
- Location: Built in NYC
- Marketing website: odozi.app

## Build Commands

```bash
# Build (requires physical device destination for FamilyControls, or use iphoneos SDK)
make build

# Build without code signing (CI)
xcodebuild -project Odyssey.xcodeproj -target Odyssey -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build

# Run tests
make test

# Clean build artifacts
make clean

# See all available commands
make help
```

## Architecture

**Pattern:** MVVM with SwiftUI + `@Observable` (iOS 17+)

**Targets:**
- **Odyssey** — Main app target
- **OdysseyDeviceActivityMonitor** — Extension that monitors device activity via DeviceActivityMonitor (runs out-of-process)
- **OdysseyDeviceActivityReport** — ExtensionKit extension that renders Screen Time reports and writes data to shared UserDefaults
- **OdysseyTests / OdysseyUITests** — Test targets

**Data layer:**
- `SwiftData` with `@Model` class `DailyEntry` (see `Odyssey/Models/DailyEntry.swift`)
- `DataContainer.swift` manages `ModelContainer` + App Group storage
- `@Attribute(originalName:)` on `feelingColorHex` and `screenTimeSeconds` enables migration from old Core Data fields
- Shared data between app and extensions via `UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")`

**Key data flow:**
1. `OdysseyApp` is the @main entry point; requests location, Screen Time, HealthKit permissions
2. `AppDelegate` registers dual background tasks: `com.odyssey.snapshot` (8 PM) and `com.odyssey.processing` (2 AM fallback)
3. `BackgroundSnapshotService` runs location + HealthKit concurrently via `async let`, reads Screen Time from shared defaults
4. `LocationCaptureService` uses `requestLocation()` single-shot + `CLGeocoder` reverse geocoding
5. `HealthKitService` fetches steps, walking distance, and sleep analysis
6. Screen Time pipeline: `TotalActivityReport.makeConfiguration()` writes to shared UserDefaults → main app reads on foreground
7. Foreground catch-up: on every `.active` scene phase, checks if today's snapshot exists and runs if missing

**Navigation (4 tabs):**
- **Today** — Greeting, entry status card, launches GuidedPromptFlowView as fullScreenCover
- **Journal** — Calendar view, searchable entry list, detail view
- **Insights** — Dashboard grid with mood trends, map, streaks, word cloud, color palette, year-in-review
- **Profile** — Screen Time report, app selection, CSV export

**Guided Prompts:**
- 8-step paged flow: Mood → Feeling → Sleep → Gratitude → Win → Tension → Journal → Drinks
- Each step skippable, completion card with animation on submit
- `GuidedPromptViewModel` manages flow state, `PromptResponses` struct holds in-progress answers

**Visualizations:**
- Swift Charts for mood trends, streak bars, year-in-review sparklines
- MapKit with color-coded mood pins
- Custom `FlowLayout` for word cloud
- `ImageRenderer` for shareable year-in-review cards

**Core Data model (legacy):** `Odyssey.xcdatamodeld` still present for migration. SwiftData handles new persistence.

**Dependency:** Lottie (SPM, ~>4.0) — used for animated Earth in Year-in-Review title card

## Key File Locations

| Area | Path |
|------|------|
| Data model | `Odyssey/Models/DailyEntry.swift` |
| Persistence | `Odyssey/Models/DataContainer.swift` |
| Background services | `Odyssey/Services/` |
| Guided prompts | `Odyssey/Views/GuidedPrompts/` |
| Prompt cards | `Odyssey/Views/GuidedPrompts/Cards/` |
| Visualizations | `Odyssey/Views/Insights/` |
| Year-in-Review | `Odyssey/Views/YearInReview/ReviewCards/` |
| Design tokens | `Odyssey/Extensions/Color+Extensions.swift` |
| Shared defaults | `Odyssey/Services/SharedDefaults.swift` |
| Feature demo tests | `OdysseyUITests/FeatureDemos/` |
| Demo base class | `OdysseyUITests/FeatureDemos/FeatureDemoBase.swift` |
| Demo recording script | `scripts/record-demo.sh` |
| Marketing website | `website/` (Next.js 15, static export, deployed to odozi.app) |
| Fastlane config | `fastlane/` |

## Developer Loop

When building a new feature, follow this flow:

1. **Implement** the feature (models, services, views)
2. **Write unit tests** in `OdysseyTests/`
3. **Write a feature demo UI test** in `OdysseyUITests/FeatureDemos/`
   - Create a new file `<FeatureName>Demo.swift` subclassing `FeatureDemoBase`
   - Add one or more `test…Demo` methods that walk through the feature at a human-readable pace
   - Use the inherited helpers (`tapTab`, `wait(for:)`, `advancePrompt`, `submitQuickEntry`, etc.)
   - Add `pause()` calls between interactions so the recorded video is watchable
   - See `FeatureDemoBase.swift` header for full instructions
4. **Record a demo** with `/demo` — this records a simulator video, uploads to Dropbox, and posts to the PR
5. **Verify** the video shows the feature working end-to-end before requesting review

## Key Conventions

- iOS 17+ target (SwiftData, new MapKit, Swift Charts)
- Dark mode enforced app-wide via `.environment(\.colorScheme, .dark)`
- Design tokens in `Color+Extensions.swift`: `.accentAmber`, `.accentTeal`, `.successGreen`, `.coralRed`, `.cardSurface`
- Colors stored as hex strings in SwiftData (see `UIColor+Extensions.swift`)
- All ViewModels use `@Observable` macro, take `ModelContext` as injected dependency
- FamilyControls/DeviceActivity APIs require a **physical device** — simulator builds will fail for extension targets
- App Group `group.com.johnlarkin.Odyssey` shared across all 3 targets
- HealthKit entitlement on main app target only
- BGTaskScheduler identifiers: `com.odyssey.snapshot`, `com.odyssey.processing`
