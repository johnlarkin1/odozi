# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Odyssey is an iOS mental wellness tracking app built with SwiftUI. It collects daily mood data, sleep quality, journal entries, and integrates Apple's Screen Time API via FamilyControls/DeviceActivity frameworks. Uses Core Data for persistence and CoreLocation for background location tracking.

## Build Commands

```bash
# Build (requires physical device destination for FamilyControls)
make build

# Run tests
make test

# Clean build artifacts
make clean

# See all available commands
make help
```

Or directly with xcodebuild:
```bash
xcodebuild -project Odyssey.xcodeproj -scheme Odyssey -configuration Debug build
xcodebuild -project Odyssey.xcodeproj -scheme Odyssey test
```

## Architecture

**Pattern:** MVVM with SwiftUI

**Targets:**
- **Odyssey** — Main app target
- **OdysseyDeviceActivityMonitor** — Extension that monitors device activity via DeviceActivityMonitor (runs out-of-process)
- **OdysseyDeviceActivityReport** — ExtensionKit extension that renders Screen Time reports using DeviceActivityReportExtension
- **OdysseyTests / OdysseyUITests** — Test targets (currently template stubs)

**Key data flow:**
1. `OdysseyApp` is the @main entry point; requests location + Screen Time permissions on appear
2. `AppDelegate` registers background refresh task (`com.odyssey.refresh`) scheduled nightly at 11:55 PM
3. `BackgroundDataFetch` (NSOperation) runs during background refresh to collect location/device data
4. `DailyEntryViewModel` manages Core Data CRUD for the `DailyEntry` entity
5. `ContentView` provides tab navigation; `HomeView` shows Lottie welcome animation

**Core Data model:** `Odyssey.xcdatamodeld` with `DailyEntry` entity (date, feeling, sleepQuality, journalEntry, drinks, win, tension, gratitude, latitude, longitude, screenTime, pickups, etc.)

**Dependency:** Lottie (SPM, ~>4.0) — used for animated Earth in HomeView

## Key Conventions

- Dark mode is enforced app-wide via `.environment(\.colorScheme, .dark)`
- Colors stored as hex strings in Core Data (see `UIColor+Extensions.swift`)
- FamilyControls/DeviceActivity APIs require a **physical device** — simulator builds will fail for extension targets
- The two extensions share the `com.apple.developer.family-controls` entitlement
