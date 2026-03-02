# Odyssey Codebase Review — 2026-03-01

## Bugs (fix now) — ALL RESOLVED (PR #31, commit `3e53109`)

| # | Area | Issue | Status |
|---|------|-------|--------|
| B1 | Screen Time | `pickups` is never written by the extension — always reads 0 | Fixed in PR #31 |
| B2 | Screen Time | Darwin notification + `lastIntervalEnd` key are dead code | Fixed in PR #31 |
| B3 | Location | `CLLocationManager` created off main thread — may silently fail | Fixed in PR #31 |
| B4 | Location | Empty `locations` array → continuation never resumes (hangs forever) | Fixed in PR #31 |
| B5 | HealthKit | Sleep hours double-counted when multiple sources (Watch + iPhone) exist | Fixed in PR #31 |
| B6 | Calendar | `ForEach(["S","M","T","W","T","F","S"], id: \.self)` — duplicate IDs cause mis-rendering | Fixed in PR #31 |
| B7 | Word Cloud | `hashValue` is randomized per launch — word colors change every time | Fixed in PR #31 |
| B8 | Data | No `#Unique` on `DailyEntry.date` — race conditions can create duplicate entries | Mitigated — `#Unique` requires iOS 18+; app-level fetch-before-insert enforced via `DailyEntryRepository` |
| B9 | Foreground | Snapshot check uses `latitude != nil` — re-runs capture endlessly if location denied | Fixed in PR #31 |
| B10 | Migration | `try?` on file copy silently swallows errors — data loss risk | Fixed in PR #31 |

## Architecture Improvements (high value) — ALL RESOLVED (PRs #32, #35)

| # | Area | Issue | Status |
|---|------|-------|--------|
| A1 | Data access | Fetch-or-create pattern duplicated in 4 places — needs a `DailyEntryRepository` | Fixed in PR #32 |
| A2 | ViewModels | `@MainActor` missing on 4 of 6 ViewModels that hold `ModelContext` | Fixed in PR #32 |
| A3 | ViewModels | `currentStreak` computed identically in 2 VMs — DRY violation | Fixed in PR #32 |
| A4 | Submit flow | 3 redundant DB fetches during guided prompt submission | Fixed in PR #32 |
| A5 | Auth | `AuthManager` is a non-functional shell — Clerk SDK never integrated | Fixed in PR #35 |
| A6 | Sync | `encryptBatch` does 500 sequential async calls — should use `TaskGroup` | Fixed in PR #32 |

## UI/UX Improvements — ALL RESOLVED (PR #33)

| # | Area | Issue | Status |
|---|------|-------|--------|
| U1 | Accessibility | Zero `accessibilityLabel` anywhere — VoiceOver completely unusable | Fixed in PR #33 |
| U2 | Performance | `CosmicBackground` runs at full display refresh (60-120fps) on every tab | Fixed in PR #33 |
| U3 | Performance | `TodayView` calls `fetchTodayEntry()` 6 times per render | Fixed in PR #33 |
| U4 | Duplication | `OverviewTabView` / `MindTabView` have ~60 lines of duplicated card grids | Fixed in PR #33 |
| U5 | Sharing | `ShareableCardRenderer` uses deprecated `UIScreen.main.scale`, hardcoded iPhone size | Fixed in PR #33 |
| U6 | Export | `ProfileView` uses UIKit scene bridge instead of `ShareLink` | Fixed in PR #33 |

## DevOps Gaps — MOSTLY RESOLVED (PR #34); D2, D3 still open

| # | Area | Issue | Status |
|---|------|-------|--------|
| D1 | CI/CD | No GitHub Actions workflows at all — zero automated testing on PRs | Fixed in PR #34 |
| D2 | Testing | UI tests are unmodified Xcode templates — zero coverage | **Open** |
| D3 | Testing | All background services have zero test coverage | **Open** |
| D4 | Linting | No SwiftLint/swift-format configured; Makefile `lint` target is a no-op | Fixed in PR #34 |
| D5 | Docker | Runs as root, no healthcheck, unpinned minor version | Fixed in PR #34 |

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
