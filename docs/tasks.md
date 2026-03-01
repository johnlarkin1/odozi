# Odyssey — Outstanding Work Breakdown

Date: 2026-03-01

> Generated from a full repo audit on 2026-03-01, post-merge of PR #11 (auth + cloud backup infrastructure).
> Findings from 5 parallel audits: Auth/Security, Data Flow, Backend API, UI/Onboarding, Test Coverage & Code Quality.

---

## P0 — Critical (Must fix before any production/TestFlight use)

### P0-1. Wire up Clerk SDK authentication (auth is entirely non-functional)

**Status:** Stubbed — every method in `AuthManager` is a no-op
**Files:** `Odyssey/Services/Auth/AuthManager.swift`, `ClerkConfiguration.swift`
**Details:** `signIn()`, `signUp()`, `signOut()`, `refreshTokenIfNeeded()`, `deleteAccount()` all have Clerk logic commented out. The app presents sign-in UI that silently does nothing. `sessionToken` is never set, so sync always fails with "Not authenticated."
**Work:**

- [ ] Integrate Clerk iOS SDK
- [ ] Implement `signIn(strategy:)` for Apple + Google
- [ ] Implement `signUp(strategy:)` for Apple + Google
- [ ] Implement `signOut()` with server-side session revocation
- [ ] Implement `refreshTokenIfNeeded()` with JWT expiry check + refresh
- [ ] Implement `deleteAccount()` calling `APIClient.deleteAccount(token:)` to purge server data
- [ ] Replace placeholder `publishableKey` in `ClerkConfiguration.swift`

### P0-2. Fix SwiftData concurrency violations (data race crashes)

**Status:** Active bugs — 4 services mutate `@Model` / `ModelContext` off the main actor
**Files:** `SyncService.swift`, `BackgroundSnapshotService.swift`, `DailyEntryViewModel.swift`, `AuthManager.swift`
**Details:**

- `SyncService` modifies `entry.needsSync` / `entry.lastSyncedAt` from async context without `@MainActor`
- `BackgroundSnapshotService` receives `ModelContext` (non-Sendable) across actor isolation boundary
- `DailyEntryViewModel.updateLocation()` mutates model properties from background thread
- `AuthManager` modifies `@Observable` UI properties (`isSignedIn`, `isLoading`) without `@MainActor`
  **Work:**
- [ ] Add `@MainActor` to `AuthManager`, `SyncService`, `DailyEntryViewModel`
- [ ] Restructure `BackgroundSnapshotService` to perform `ModelContext` operations on main actor
- [ ] Audit all `async` methods that touch SwiftData for proper actor isolation

### P0-3. Persist auth token in Keychain (not in-memory)

**Status:** `sessionToken` is a plain `String?` that vanishes on app restart
**File:** `Odyssey/Services/Auth/AuthManager.swift:29`
**Work:**

- [ ] Store session/refresh tokens via `KeychainService`
- [ ] Restore tokens in `initialize()` on app launch
- [ ] Clear tokens on `signOut()` and `deleteAccount()`

### P0-4. Fix backend compilation error — `cursor` variable redeclared

**File:** `odyssey-api/src/routes/entries.ts:108,149`
**Details:** `cursor` is declared twice in the same scope (query param + response cursor). Will fail with `noUnusedLocals: true`.
**Work:**

- [ ] Rename response cursor to `nextCursor`
- [ ] Remove unused `pgPolicy` import in `schema.ts`

### P0-5. Account deletion must purge server-side data

**Files:** `AuthManager.swift:99-109`, `AccountView.swift:74-78`
**Details:** `deleteAccount()` clears local state only. `APIClient.deleteAccount(token:)` exists but is never called. Cloud data persists after user "deletes" account — GDPR/privacy violation.
**Work:**

- [ ] Call `APIClient.deleteAccount(token:)` from `AuthManager.deleteAccount()`
- [ ] Confirm server responds with 200 before clearing local state
- [ ] Show error to user if server deletion fails

### P0-6. Implement real rate limiting for Cloudflare Workers

**File:** `odyssey-api/src/middleware/rate-limit.ts`
**Details:** In-memory `Map` is per-isolate and evicted on every cold start. Provides zero protection on Workers.
**Work:**

- [ ] Replace with Cloudflare Rate Limiting Rules (wrangler.toml / dashboard) or Durable Objects
- [ ] Remove the in-memory rate limiter

---

## P1 — High (Should fix before beta / broader testing)

### P1-1. Encrypt all sensitive metadata in sync payload

**Files:** `SyncService.swift:140-163`, `SyncPayload.swift:18-25`
**Details:** Mood (`feeling`), sleep quality, alcohol consumption (`drinks`), step count, sleep hours, screen time, pickups, and `feelingColorHex` are all sent in plaintext. These form a detailed behavioral fingerprint.
**Work:**

- [ ] Encrypt `feeling`, `sleepQuality`, `drinks`, `sleepHours`, `stepCount`, `walkingDistanceMeters`, `screenTimeSeconds`, `pickups`, `feelingColorHex` before upload
- [ ] Update `SyncDownloadEntry` to decrypt these fields on restore
- [ ] Update backend schema if needed (store as encrypted blobs instead of typed columns)

### P1-2. Implement sync conflict resolution beyond last-write-wins

**File:** `SyncService.swift:180-184`
**Details:** Current merge is `updatedAt >=` — loser is silently discarded. No field-level merge, no user notification, no conflict log.
**Work:**

- [ ] Implement field-level merge (prefer non-nil over nil, merge text by recency)
- [ ] Or: detect conflicts and surface to user for manual resolution
- [ ] Add conflict logging for debugging

### P1-3. Add database-level RLS or compensating controls

**File:** `odyssey-api/src/db/rls.ts`
**Details:** `withRLS()` is a no-op. Data isolation relies solely on `eq(entries.userId, userId)` in each query. One missing WHERE clause exposes all users.
**Work:**

- [ ] Explore Neon WebSocket driver for real Postgres RLS
- [ ] Or: create a `scopedQuery(db, userId)` wrapper that auto-injects userId filter
- [ ] Add integration tests verifying cross-user data isolation

### P1-4. Protect recovery key from clipboard sniffing

**Files:** `AccountView.swift:102`, `BackupPromptModal.swift:158`
**Details:** Raw AES-256 master key copied to `UIPasteboard.general` — readable by any foreground app, synced via Universal Clipboard.
**Work:**

- [ ] Set `UIPasteboard.general.setItems([...], options: [.expirationDate: Date().addingTimeInterval(60)])` for auto-expiry
- [ ] Warn user about clipboard risks
- [ ] Consider alternative export: QR code, file export, or password-derived key

### P1-5. Fix silent error swallowing in auth UI

**Files:** `SignInView.swift:23,29`, `BackupPromptModal.swift:96,102`, `AccountView.swift:76`
**Details:** All auth actions use `try?` — errors are silently discarded. `BackupPromptModal` has no error display at all.
**Work:**

- [ ] Replace `try?` with `do/catch` and set `authManager.error`
- [ ] Add error display to `BackupPromptModal` (match `SignInView` pattern)
- [ ] Show confirmation/error on `deleteAccount()`

### P1-6. Validate client timestamps server-side

**File:** `odyssey-api/src/routes/entries.ts:59-60`, `validation.ts:29-30`
**Details:** `createdAt` and `updatedAt` are accepted as arbitrary client strings. A client can set `updatedAt` to year 2099 to always "win" sync conflicts.
**Work:**

- [ ] Validate ISO 8601 format in Zod schema
- [ ] Reject timestamps more than ±24h from server time
- [ ] Set `updatedAt` server-side on upsert (authoritative)

### P1-7. Add request body size limits and string length constraints

**Files:** `odyssey-api/src/routes/entries.ts:13`, `odyssey-api/src/utils/validation.ts`
**Details:** No body size limit. String fields (journal, gratitude, etc.) accept unlimited length. 100 entries × unbounded strings = potential Worker OOM.
**Work:**

- [ ] Add `.max(10000)` or similar to text fields in Zod schemas
- [ ] Add `.regex(/^#[0-9a-fA-F]{6}$/)` to `feelingColorHex`
- [ ] Configure Hono body size middleware

### P1-8. Fix CORS — restrict or remove for mobile-only API

**File:** `odyssey-api/src/index.ts:14`
**Details:** `cors()` defaults to `Access-Control-Allow-Origin: *`. Mobile apps don't need CORS.
**Work:**

- [ ] Remove CORS middleware entirely (mobile-only API)
- [ ] Or restrict to specific origins if web admin panel is planned

### P1-9. Guard force unwraps on App Group container URLs

**Files:** `DataContainer.swift:31-33,45-46`, `SharedDefaults.swift:7`
**Details:** Force unwraps on `containerURL(forSecurityApplicationGroupIdentifier:)!` and `UserDefaults(suiteName:)!` — crash on misconfigured entitlements.
**Work:**

- [ ] Replace with `guard let` + graceful error / fallback to local-only storage
- [ ] Surface error in `DataStoreErrorView` if App Group unavailable

### P1-10. DataRetentionService needs user confirmation

**File:** `Odyssey/Services/Retention/DataRetentionService.swift:8-34`
**Details:** Silently deletes entries older than 1 year for non-account users. No warning, no undo. If `hasAccount` is incorrectly false (auth bug), backed-up data gets deleted.
**Work:**

- [ ] Add user confirmation before deletion
- [ ] Or: only run retention after explicit user consent in settings
- [ ] Add logging of what was deleted

---

## P2 — Medium (Should fix before v1.0 release)

### P2-1. Add `@MainActor` or actor isolation to remaining ViewModels

**Files:** `OnboardingViewModel.swift`, `InsightsViewModel.swift`, `JournalViewModel.swift`
**Details:** ViewModels using `@Observable` should be `@MainActor` for thread safety.

### P2-2. Add JWT issuer and audience validation

**File:** `odyssey-api/src/auth/clerk.ts:17`
**Work:** Add `issuer` and `audience` options to `jwtVerify()` call.

### P2-3. Add `syncID` / server-side unique identifier to DailyEntry

**Files:** `DailyEntry.swift`, `SyncPayload.swift`, `SyncService.swift`
**Details:** Currently matched by `entryDate` only. No delta/incremental sync capability. `restoreFromCloud` downloads everything every time.

### P2-4. Add background sync trigger

**Files:** `OdysseyAppDelegate.swift`, `SyncService.swift`
**Details:** `needsSync = true` is set in background snapshot and journal submit, but sync only runs on foreground. Entries can sit unsynced for days.

### P2-5. Fix TabView swipe bypass in onboarding

**File:** `OnboardingFlowView.swift:19-24`
**Details:** `.tabViewStyle(.page)` allows swiping past permission steps. Users can reach account/completion step without granting any permissions.
**Work:** Disable swipe (use `.tabViewStyle(.page(indexDisplayMode: .never))` with gesture disabled) or validate permissions on each step.

### P2-6. Fix N+1 query pattern in batch entry upsert

**File:** `odyssey-api/src/routes/entries.ts:34-89`
**Details:** 100 sequential DB round-trips for a 100-entry batch. Use Drizzle batch insert or `Promise.all()`.

### P2-7. Disable buttons during loading states

**Files:** `BackupPromptModal.swift:93-103`, `SignInView.swift:20-31`, `AccountView.swift:19-35`
**Details:** Auth/sync buttons remain tappable during loading. Users can trigger multiple concurrent requests.

### P2-8. Add location permission callback handling in onboarding

**File:** `OnboardingViewModel.swift:60-63`
**Details:** `requestLocationAccess()` calls system dialog then immediately advances. Permission dialog overlaps next step.

### P2-9. Add timeout to LocationCaptureService

**File:** `Odyssey/Services/LocationCaptureService.swift:18-27`
**Details:** `objc_setAssociatedObject` delegate pattern with no timeout. If CLLocationManager is deallocated before callback, async call hangs forever.

### P2-10. Fix SwiftData store migration error handling

**File:** `DataContainer.swift:52-60`
**Details:** `try?` on file copy can silently lose all data during App Group migration.

### P2-11. Add `updated_at` trigger in database

**File:** `odyssey-api/drizzle/migrations/0000_initial.sql:39`
**Details:** No auto-update trigger. Direct SQL updates won't update `updated_at`, breaking sync cursor.

### P2-12. Encrypt SwiftData store at rest

**File:** `DataContainer.swift:17-24`
**Details:** SQLite store is plaintext. Readable on jailbroken device / forensic extraction.

### P2-13. Add copy confirmation for recovery key

**Files:** `AccountView.swift:101-103`, `BackupPromptModal.swift:157-159`
**Details:** No visual feedback (toast/haptic) on clipboard copy.

---

## P3 — Low (Polish / tech debt for future iterations)

### P3-1. Add structured logging to backend

**File:** `odyssey-api/src/middleware/error-handler.ts`
**Details:** Only `console.error` exists. No request IDs, no structured logging, no observability.

### P3-2. Add security headers to API

**File:** `odyssey-api/src/index.ts`
**Details:** Missing `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`.

### P3-3. Add index on `sync_log.user_id`

**File:** `odyssey-api/drizzle/migrations/0000_initial.sql`
**Details:** CASCADE delete on user requires sequential scan of unindexed `sync_log`.

### P3-4. Populate `device_id` in sync log

**File:** `odyssey-api/src/routes/entries.ts:92-95`
**Details:** `sync_log.device_id` column exists but is never written.

### P3-5. Extract shared `signInButton` component

**Files:** `SignInView.swift`, `BackupPromptModal.swift`
**Details:** Identical Apple/Google sign-in button implementations duplicated across views.

### P3-6. Use constants for UserDefaults keys

**File:** `OdysseyApp.swift:64,67`
**Details:** `"hasSeenBackupPrompt"` and `"hasCompletedOnboarding"` are raw strings. Extract to constants.

### P3-7. Fix visual inconsistencies

- `AccountCard.swift` uses `Color.accentTeal` for "Create Account" vs `BackupPromptModal` uses `Color.accentAmber` for the same action
- `ProfileView.swift` Account section missing `.listRowBackground(Color.cardSurface)`

### P3-8. Fix accessibility issues

- `AccountCard.swift:109-117` — bullet points lack VoiceOver labels
- `SyncStatusBanner.swift` — no `accessibilityElement(children: .combine)`
- `OnboardingNavigationBar.swift` — hidden back button still focusable by VoiceOver
- `DataStoreErrorView` — no accessibility labels or recovery actions

### P3-9. Clean up test suite

- Delete empty `OdysseyTests.swift` scaffold
- Fix `PhotoLibraryServiceTests` (assertions test nothing useful)
- Fix `PromptModelsTests:34` — references non-existent `step.emoji` property (should be `iconName`)
- Replace `try!` / force unwraps in `EncryptionServiceTests` with `XCTUnwrap`

### P3-10. Add key rotation mechanism

**Files:** `EncryptionService.swift`, `KeychainService.swift`
**Details:** No way to rotate encryption key. Compromised key exposes all historical ciphertexts.

### P3-11. Add certificate pinning

**File:** `APIClient.swift:38`
**Details:** `URLSession.shared` with no certificate pinning. Vulnerable to MITM with compromised trust store.

### P3-12. Remove unused `email` column or populate it

**File:** `odyssey-api/src/db/schema.ts:15`
**Details:** `email` column exists but is never written to in any route.

### P3-13. Photos not included in cloud backup

**Files:** `DailyEntry.swift:44-45`, `SyncPayload.swift`
**Details:** `attachedPhotoData` and `autoPhotoIdentifiers` are local-only. Users may expect backup to include photos.

### P3-14. CSV export bypasses encryption

**File:** `ProfileView.swift:95-122`
**Details:** Export writes all PII (journal text, location, mood, health data, alcohol) to unencrypted temp file shared via `UIActivityViewController`.

---

## Test Coverage Priorities

| Service                     | Risk                                             | Recommended Tests                                                                    |
| --------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `SyncService`               | **Critical** — handles encryption, upload, merge | Mock APIClient, test encrypt→upload→download→decrypt roundtrip, test merge conflicts |
| `AuthManager`               | **Critical** — gates all cloud features          | Mock Clerk SDK, test sign-in/out state transitions, token refresh                    |
| `DataRetentionService`      | **High** — deletes user data                     | Test retention window, account vs no-account behavior, edge cases                    |
| `APIClient`                 | **High** — all network communication             | Mock URLSession, test request building, response validation, error mapping           |
| `KeychainService`           | **High** — encryption key storage                | Test store/retrieve/delete cycle, test behavior when key missing                     |
| `BackgroundSnapshotService` | **Medium** — background data capture             | Test concurrent capture, test partial failure handling                               |
| `OnboardingViewModel`       | **Medium** — user first experience               | Test step navigation, permission request sequencing                                  |
| `LocationCaptureService`    | **Medium** — timeout and error handling          | Test timeout, test location manager errors                                           |

---

## Architecture Diagram (Current State)

```
┌─────────────────────────────────────────────────────────────┐
│  iOS App (Odyssey)                                          │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ OnboardingVM │    │  TodayView   │    │  ProfileView  │  │
│  │  (no auth    │    │  (journal    │    │  (account,    │  │
│  │   wired)     │    │   submit)    │    │   sync,       │  │
│  │              │    │              │    │   export)     │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                    │          │
│  ┌──────▼───────────────────▼────────────────────▼───────┐  │
│  │              AuthManager (ALL STUBBED)                 │  │
│  │  signIn: no-op  │  signOut: local only  │  token: nil │  │
│  └──────────────────────────┬────────────────────────────┘  │
│                             │                               │
│  ┌──────────────────────────▼────────────────────────────┐  │
│  │                    SyncService                         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌─────────────────┐ │  │
│  │  │ Encryption │  │  APIClient │  │ Merge (LWW,     │ │  │
│  │  │ (AES-GCM,  │  │ (placeholder│  │ no conflict    │ │  │
│  │  │  partial)  │  │  URL)      │  │  resolution)   │ │  │
│  │  └────────────┘  └────────────┘  └─────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │   SwiftData    │  │  SharedDefaults │  │   Keychain   │  │
│  │  (unencrypted  │  │  (screen time)  │  │  (AES key,   │  │
│  │   at rest)     │  │                 │  │  no token)   │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                             │
                      ┌──────▼──────┐
                      │  odyssey-api │  (Cloudflare Worker)
                      │  - No RLS    │
                      │  - No rate   │
                      │    limiting  │
                      │  - Wildcard  │
                      │    CORS      │
                      │  - N+1 upsert│
                      └──────┬──────┘
                             │
                      ┌──────▼──────┐
                      │   Neon DB   │
                      │  (Postgres) │
                      └─────────────┘
```
