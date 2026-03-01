# Odyssey Codebase Review — 2026-03-01

## Bugs (fix now)

| # | Area | Issue |
|---|------|-------|
| B1 | Screen Time | `pickups` is never written by the extension — always reads 0 |
| B2 | Screen Time | Darwin notification + `lastIntervalEnd` key are dead code |
| B3 | Location | `CLLocationManager` created off main thread — may silently fail |
| B4 | Location | Empty `locations` array → continuation never resumes (hangs forever) |
| B5 | HealthKit | Sleep hours double-counted when multiple sources (Watch + iPhone) exist |
| B6 | Calendar | `ForEach(["S","M","T","W","T","F","S"], id: \.self)` — duplicate IDs cause mis-rendering |
| B7 | Word Cloud | `hashValue` is randomized per launch — word colors change every time |
| B8 | Data | No `#Unique` on `DailyEntry.date` — race conditions can create duplicate entries |
| B9 | Foreground | Snapshot check uses `latitude != nil` — re-runs capture endlessly if location denied |
| B10 | Migration | `try?` on file copy silently swallows errors — data loss risk |

## Architecture Improvements (high value)

| # | Area | Issue |
|---|------|-------|
| A1 | Data access | Fetch-or-create pattern duplicated in 4 places — needs a `DailyEntryRepository` |
| A2 | ViewModels | `@MainActor` missing on 4 of 6 ViewModels that hold `ModelContext` |
| A3 | ViewModels | `currentStreak` computed identically in 2 VMs — DRY violation |
| A4 | Submit flow | 3 redundant DB fetches during guided prompt submission |
| A5 | Auth | `AuthManager` is a non-functional shell — Clerk SDK never integrated |
| A6 | Sync | `encryptBatch` does 500 sequential async calls — should use `TaskGroup` |

## UI/UX Improvements

| # | Area | Issue |
|---|------|-------|
| U1 | Accessibility | Zero `accessibilityLabel` anywhere — VoiceOver completely unusable |
| U2 | Performance | `CosmicBackground` runs at full display refresh (60-120fps) on every tab |
| U3 | Performance | `TodayView` calls `fetchTodayEntry()` 6 times per render |
| U4 | Duplication | `OverviewTabView` / `MindTabView` have ~60 lines of duplicated card grids |
| U5 | Sharing | `ShareableCardRenderer` uses deprecated `UIScreen.main.scale`, hardcoded iPhone size |
| U6 | Export | `ProfileView` uses UIKit scene bridge instead of `ShareLink` |

## DevOps Gaps

| # | Area | Issue |
|---|------|-------|
| D1 | CI/CD | No GitHub Actions workflows at all — zero automated testing on PRs |
| D2 | Testing | UI tests are unmodified Xcode templates — zero coverage |
| D3 | Testing | All background services have zero test coverage |
| D4 | Linting | No SwiftLint/swift-format configured; Makefile `lint` target is a no-op |
| D5 | Docker | Runs as root, no healthcheck, unpinned minor version |

## Detailed Agent Reports

### Architecture & Data Layer

- `DailyEntry` is a flat model with 23 fields spanning 4 concerns. No relationships.
- Migration uses `try? fileManager.copyItem(...)` and fragile `.store`/`.sqlite` string replacement.
- No `VersionedSchema` or `SchemaMigrationPlan`.
- `GuidedPromptViewModel.submit()` creates an ephemeral `DailyEntryViewModel` inline, triggering unnecessary DB fetches.
- `InsightsViewModel.loadEntries()` loads all entries into memory — no `@Query` integration.
- `SyncService.encryptBatch` is O(n) sequential — 500 async calls per batch.
- `PhotoLibraryService.shared` is an untestable singleton.

### Services & Background Tasks

- `BackgroundSnapshotService` properly uses `actor` + `async let` for concurrent capture.
- Both BGTask identifiers registered correctly; expiration handler cancels in-flight Task.
- `CLLocationManager` initialized on non-main-thread actor — Apple requires main thread.
- `HealthKitService` doesn't deduplicate overlapping sleep samples from multiple sources.
- `SharedDefaults.setScreenTime` writes 3 keys non-atomically (best possible with UserDefaults).
- `AuthManager` is entirely scaffolded with TODOs — Clerk SDK never integrated.

### UI/Views

- Guided prompts flow is clean (8-step TabView + PromptCardContainer pattern).
- Zero accessibility labels anywhere in the entire Views directory.
- `CosmicCanvasView` uses `TimelineView(.animation)` at full refresh rate on every tab.
- `CalendarHeatmapView` has duplicate ForEach IDs ("T" and "S" appear twice).
- `FlowLayout` colorForWord uses `hashValue` — randomized per launch (SE-0206).
- `ShareableCardRenderer` uses deprecated `UIScreen.main.scale`, hardcodes iPhone 14 Pro size.
- `TodayView.body` calls `fetchTodayEntry()` 6 times per render.
- Year-in-review card animations replay on every back-navigation (onAppear re-fires).

### Testing & DevOps

- Core ViewModel tests are genuinely good (in-memory SwiftData, real logic).
- UI tests are unmodified Xcode templates — zero real coverage.
- No CI/CD workflows exist. No GitHub Actions.
- No SwiftLint/swift-format. Makefile `lint` target is a no-op.
- Dockerfile is multi-stage but runs as root with no healthcheck.
- Single SPM dependency (Lottie 4.3.4) pinned to exact revision — excellent.
