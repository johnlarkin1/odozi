# Odyssey — Task Backlog

> Generated 2026-03-01 from full codebase audit (130 Swift files, 12 Rust source files, 15 test files)
>
> **Legend:** P0 = blocker, P1 = critical, P2 = high, P3 = medium, P4 = nice-to-have

---

## 1. App Store Prep

### P0 — Submission Blockers

- [ ] **Submit FamilyControls entitlement request to Apple** — Required for all 3 bundle IDs (`com.johnlarkin.Odyssey`, `.OdysseyDeviceActivityMonitor`, `.OdysseyDeviceActivityReport`). Takes 1–30+ days. Start immediately. https://developer.apple.com/contact/request/family-controls-distribution
- [ ] **Create App Store Connect listing** — App name (`Odyssey - Wellness Journal`), subtitle, category (Health & Fitness / Lifestyle), age rating (4+)
- [ ] **Write App Store description** — Draft exists in `docs/APP_STORE_PUBLICATION_PLAN.md`, needs final polish and paste into ASC
- [ ] **Capture App Store screenshots** — 6 screenshots @ 1320×2868px (iPhone 15 Pro Max). Cover: Today tab, guided prompts, insights dashboard, year-in-review, journal, journey explorer
- [ ] **Finalize App Store keywords** — 100 char limit. Draft: `journal,mood,tracker,wellness,mental,health,gratitude,mindful,diary,reflection,self-care,daily,log`

### P1 — Code Fixes for Submission

- [ ] **Replace `print()` with `os.Logger`** — 11 instances of `print()` remain; App Review may flag debug logging
- [ ] **Fix force unwraps / force casts** — 3 crash-risk sites identified in publication plan audit
- [ ] **Handle `ModelContainer` init failure gracefully** — Currently `fatalError`; show recovery UI instead
- [ ] **Wrap `SampleData` in `#if DEBUG`** — Ensure preview/sample data doesn't ship in Release builds
- [ ] **Clean up PreviewProvider leftovers** — Remove or gate any development-only code

### P1 — CI/CD & Signing

- [ ] **Set up Fastlane** — Create `Fastfile` with `beta` (TestFlight) and `release` (App Store) lanes, `Appfile`, `Matchfile`
- [ ] **Configure code signing for CI** — Fastlane `match` for provisioning profiles + certificates for all 3 targets
- [ ] **Add TestFlight upload lane** — `fastlane beta` should build Release, increment build number, upload to TestFlight
- [ ] **Add App Store submission lane** — `fastlane release` for final submission
- [ ] **Create `release.yml` GitHub Actions workflow** — Trigger on tag push, runs Fastlane beta or release
- [ ] **Add SwiftLint step to CI** — Currently only runs locally via `make lint`; add to `.github/workflows/ci.yml`
- [ ] **Add code coverage reporting** — Integrate Codecov or similar; currently no coverage tracking
- [ ] **Automate version/build number bumping** — Currently manual (`1.0` build `1`)

### P2 — Metadata & Polish

- [ ] **Add privacy policy link to Settings** — Policy exists at `https://johnlarkin1.github.io/assets/html/odyssey/privacy.html` but isn't linked in-app
- [ ] **Add terms of service link to Settings**
- [ ] **Create App Preview video** — Optional but recommended; 15–30s walkthrough of daily flow
- [ ] **Finalize app icon** — `designs/odyssey-icon-cosmic-1024.png` exists; verify it's wired into asset catalog
- [ ] **Privacy Nutrition Labels** — Fill out App Privacy section in ASC (data types collected, linked to identity, etc.)

---

## 2. Feature Work

### P1 — Engagement & Retention

- [ ] **Implement local notifications / daily reminders** — `UNUserNotificationCenter` scheduling at user-configurable time. Add permission request to onboarding. Add toggle + time picker to Settings. This is the single biggest engagement gap.
- [ ] **Add push notifications for sync events** — APNs registration + backend support for sync completion, weekly summary nudges
- [ ] **Offline sync retry queue** — Entries marked `needsSync = true` have no retry/backoff strategy. Implement exponential backoff with `URLSession` background transfers or on-foreground retry.

### P2 — Settings & User Control

- [ ] **Expand Settings screen** — Currently minimal. Add sections for:
  - Notification preferences (time, frequency)
  - Data retention policy (user-controlled, not just auto >1 year)
  - Background capture granularity (toggle location, HealthKit, Screen Time individually)
  - Export format options (JSON, PDF beyond current CSV)
- [ ] **Add offline status indicator** — Show sync state in UI when device is offline
- [ ] **Persist/export recovery key** — Currently generated but ephemeral. Add QR code export or file backup option.

### P3 — Visualizations & Analytics

- [ ] **Add iOS Widgets (WidgetKit)** — Streak counter, today's mood, entry status at a glance
- [ ] **Add sharing for individual entries** — Currently only year-in-review cards are shareable
- [ ] **Weekly/monthly summary cards** — Shareable digest beyond annual review
- [ ] **Expand correlation dashboard** — Deeper UI for exploring metric relationships

### P4 — Nice-to-Have

- [ ] **Theme customization** — Light mode option, accent color picker (currently dark-only)
- [ ] **Spotlight search indexing** — `CSSearchableIndex` for journal entries
- [ ] **Goals/habits tracking** — Prescriptive layer on top of reflective journaling
- [ ] **iPad layout** — Adaptive layouts for larger screens
- [ ] **Remove legacy Core Data model** — `Odyssey.xcdatamodeld` still present; can be removed once migration window closes

---

## 3. Testing

### P1 — Critical Service Tests (zero coverage today)

- [ ] **Create test utilities & mocks** — `MockLocationService`, `MockHealthKitService`, `MockAPIClient`, `MockPhotoLibraryService`, `TestDataBuilder`, `XCTest+Helpers`
- [ ] **Test `LocationCaptureService`** — Single location request, reverse geocoding, error handling (no location, permission denied)
- [ ] **Test `HealthKitService`** — Step/distance/sleep queries, authorization, availability checks
- [ ] **Test `BackgroundSnapshotService`** — Concurrent location + HealthKit, Screen Time from UserDefaults, snapshot assembly
- [ ] **Test `AuthManager`** — Sign-in/out flows, token management, error handling
- [ ] **Test `APIClient`** — Request building, error scenarios (network, auth, server, decoding), retry logic
- [ ] **Test `SyncService`** — Batch processing, conflict resolution, encryption/decryption during sync, status tracking

### P2 — ViewModel & Service Tests

- [ ] **Test `JournalViewModel`** — Entry loading, date filtering, list sorting
- [ ] **Test `OnboardingViewModel`** — Step navigation, permission request integration
- [ ] **Test `JourneyExplorerViewModel`** — Entry filtering, camera positioning, photo loading
- [ ] **Test `YearInReviewViewModel`** — Year data loading, progress calculation
- [ ] **Test `CorrelationService`** — Pearson correlation, insight text generation, minimum data point handling
- [ ] **Test `TrendCalculator`** — Period-over-period comparison, direction/percentage, flat trend detection
- [ ] **Test `DataRetentionService`** — Old entry deletion, retention policy, cooldown enforcement
- [ ] **Test `PhotoLibraryService`** — Asset fetching, thumbnail loading, permission handling

### P2 — UI Tests

- [ ] **UI test: Guided prompt flow** — Complete 8-step journey, verify data persistence
- [ ] **UI test: Journal entry creation & editing** — Create, view detail, edit fields
- [ ] **UI test: Tab navigation** — Today → Journal → Insights → Profile
- [ ] **UI test: Calendar interactions** — Month navigation, date selection
- [ ] **UI test: Insights dashboard** — Tab switching, chart rendering
- [ ] **UI test: Year-in-review card swiping** — Page through all 10 cards
- [ ] **UI test: Auth flows** — Sign-up, sign-in, sign-out
- [ ] **UI test: Onboarding** — Permission request screens, skip functionality

### P3 — Infrastructure

- [ ] **Create `.xctestplan`** — Centralized test configuration
- [ ] **Add performance benchmarks** — Baseline for data loading, chart rendering, sync operations
- [ ] **Add integration tests** — ViewModel → Service → Model chains, cross-tab data updates
- [ ] **Wire code coverage into CI** — `xcodebuild` coverage flag + report upload

---

## 4. Backend (Rust)

### P0 — Security

- [ ] **Add PostgreSQL Row-Level Security (RLS)** — Currently data isolation relies solely on WHERE clauses; one missing `user_id` filter = full data breach
- [ ] **Add security headers** — `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `X-Frame-Options: DENY`
- [ ] **Validate JWT issuer and audience** — `auth.rs` currently only checks signature + `sub` claim; add `iss` and `aud` validation

### P1 — Testing

- [ ] **Add auth tests** — Valid/invalid tokens, JWKS cache refresh, missing Authorization header, expired tokens
- [ ] **Add entry CRUD tests** — Create, read, update (upsert), delete; verify field validation
- [ ] **Add validation tests** — Date ranges, string lengths, numeric bounds, hex color format
- [ ] **Add data isolation tests** — Verify user A cannot read/modify user B's entries
- [ ] **Add rate limiter tests** — IP extraction, window reset, over-limit 429 response
- [ ] **Add key backup tests** — Store, retrieve, overwrite, size limits

### P1 — Database

- [ ] **Set up database migration tooling** — `sqlx-cli` migrations for schema versioning. Currently tables created manually via Neon console.
- [ ] **Add indexes on frequently queried columns** — `entries(user_id, entry_date)`, `entries(user_id, updated_at)`, `sync_log(user_id)`
- [ ] **Configure automated backups** — Neon may handle this; verify and document recovery procedure

### P2 — Observability & Reliability

- [ ] **Add request ID correlation** — Generate UUID per request, include in all log lines for tracing
- [ ] **Add error tracking (Sentry)** — Catch panics and 500s with full context
- [ ] **Add health check dashboard** — Response time, error rate, active connections
- [ ] **Create `docker-compose.yml`** — Local dev with PostgreSQL + backend for contributor onboarding
- [ ] **Tighten CORS policy** — Currently `very_permissive()`; restrict to app's actual origins

### P3 — Documentation

- [ ] **Generate OpenAPI spec** — Use `utoipa` crate for auto-generation from route handlers
- [ ] **Write API authentication guide** — Clerk token acquisition → header attachment → refresh flow
- [ ] **Document sync protocol** — Delta sync cursor semantics, upsert behavior, cascade deletes
- [ ] **Add curl examples per endpoint** — For developer onboarding and debugging

---

## 5. Accessibility & Quality

### P2 — Accessibility Gaps

- [ ] **Respect `UIAccessibility.isReduceMotionEnabled`** — Cosmic background, transitions, and completion animations don't check this flag
- [ ] **Add custom accessibility rotor actions** — Common flows (start entry, view insights) as rotor shortcuts
- [ ] **Improve chart accessibility** — VoiceOver descriptions for Swift Charts, map pins, word cloud elements

### P3 — Code Quality

- [ ] **Resolve remaining OnboardingViewModel TODO** — Line 54: "Present sign-up sheet via AuthManager when Clerk SDK is integrated" — Clerk is now integrated (PR #35); clean up or remove
- [ ] **Add crash reporting (Sentry/Crashlytics)** — No crash reporting exists; critical for post-launch monitoring
- [ ] **Add analytics events** — Track key flows (entry completion rate, feature adoption, sync success rate)
- [ ] **Handle permission revocation mid-session** — Location/HealthKit permissions revoked while app is foregrounded aren't re-requested

---

## Summary

| Category | P0 | P1 | P2 | P3 | P4 | Total |
|----------|----|----|----|----|-----|-------|
| App Store Prep | 5 | 13 | 5 | 0 | 0 | **23** |
| Feature Work | 0 | 3 | 4 | 4 | 5 | **16** |
| Testing (iOS) | 0 | 7 | 10 | 4 | 0 | **21** |
| Backend (Rust) | 3 | 8 | 5 | 4 | 0 | **20** |
| Accessibility & Quality | 0 | 0 | 3 | 4 | 0 | **7** |
| **Total** | **8** | **31** | **27** | **16** | **5** | **87** |

### Suggested Execution Order

1. **Week 1:** Submit FamilyControls request (P0), fix code issues (P1), set up Fastlane + CI signing (P1)
2. **Week 2:** App Store metadata + screenshots (P0), create test mocks + critical service tests (P1), backend security fixes (P0)
3. **Week 3:** TestFlight beta upload, backend tests (P1), local notifications (P1), offline sync queue (P1)
4. **Week 4:** UI tests (P2), settings expansion (P2), accessibility fixes (P2)
5. **Ongoing:** Backend docs (P3), widgets (P3), polish (P4)
