# Odyssey — Outstanding Work Breakdown

Date: 2026-03-01 (last updated)

> Generated from a full repo audit on 2026-03-01, post-merge of PR #11.
> Updated after completion of P0 critical fixes + Rust backend rewrite (PRs #25–#30).

---

## Completed

### P0-1. Wire up Clerk SDK authentication — PARTIALLY DONE
- [x] `deleteAccount()` calls server DELETE /account before clearing local state
- [x] `refreshTokenIfNeeded()` wired with Keychain persistence
- [x] Removed unused `emailPassword` auth strategy
- [x] `ClerkConfiguration.swift` reads publishable key from xcconfig/Info.plist
- [ ] **Remaining:** Add Clerk iOS SDK via SPM in Xcode
- [ ] **Remaining:** Implement `signIn(strategy:)` for Apple + Google using Clerk SDK
- [ ] **Remaining:** Implement `signUp(strategy:)` for Apple + Google using Clerk SDK
- [ ] **Remaining:** Implement `signOut()` with Clerk SDK session revocation
- [ ] **Remaining:** Test end-to-end auth flow on device

### P0-2. Fix SwiftData concurrency violations — DONE
- [x] Added `@MainActor` to `AuthManager`, `SyncService`, `DailyEntryViewModel`, `GuidedPromptViewModel`
- [x] Refactored `BackgroundSnapshotService` to return `SnapshotData` (Sendable) instead of taking `ModelContext`
- [x] Updated `OdysseyApp.swift` and `OdysseyAppDelegate.swift` callers

### P0-3. Persist auth token in Keychain — DONE
- [x] Added `storeAuthToken`, `retrieveAuthToken`, `deleteAuthToken` to `KeychainService`
- [x] Wired into `AuthManager` (initialize, signOut, deleteAccount)
- [x] Tests passing (`KeychainServiceAuthTokenTests.swift`)

### P0-4. Backend compilation error — RESOLVED (old TS backend replaced)
- [x] Entire TypeScript/Cloudflare Workers backend replaced with Rust/Axum

### P0-5. Account deletion must purge server-side data — DONE
- [x] `deleteAccount()` calls `APIClient.deleteAccount(token:)` before clearing local state
- [x] `AccountView` shows error if server deletion fails
- [x] User stays signed in on failure so they can retry

### P0-6. Real rate limiting — DONE
- [x] IP-based rate limiter (60 req/60s) in Rust backend
- [x] Old in-memory Cloudflare Workers rate limiter eliminated

### Backend Rewrite — DONE
- [x] Rust/Axum backend (`odyssey-server/`) deployed to Render
- [x] Clerk JWT verification middleware (RS256, JWKS auto-refresh)
- [x] Entry CRUD routes (POST/GET/DELETE)
- [x] Account deletion with cascade
- [x] Key backup routes (PUT/GET)
- [x] Rate limiting, CORS, structured logging
- [x] Multi-stage Dockerfile, deployed on Render
- [x] Database tables created in Neon Postgres

### Environment Configuration — DONE
- [x] `Odyssey.xcconfig` (gitignored) for iOS secrets
- [x] `ServerConfiguration.swift` reads API URL from Info.plist
- [x] `ClerkConfiguration.swift` reads publishable key from Info.plist
- [x] `.env.example` for server-side secrets
- [x] `make update-secret-template` Makefile target

---

## P0 — Critical (Must fix before any production/TestFlight use)

### P0-1. Finish Clerk SDK integration (auth still non-functional)

**Status:** Code scaffolded, but Clerk iOS SDK not yet added as dependency
**Files:** `AuthManager.swift`, `ClerkConfiguration.swift`, `OdysseyApp.swift`
**Details:** `signIn()`, `signUp()`, `signOut()` still have Clerk logic commented out. The publishable key now reads from xcconfig, but the actual Clerk SDK package hasn't been added via SPM. Until this is done, auth doesn't work and sync will fail.
**Work:**

- [ ] Add Clerk iOS SDK via SPM in Xcode (`https://github.com/clerk/clerk-ios`)
- [ ] Call `Clerk.shared.load()` in `OdysseyApp.swift` `.task` modifier
- [ ] Implement `signIn(strategy:)` for Apple + Google
- [ ] Implement `signUp(strategy:)` (delegates to signIn for OAuth)
- [ ] Implement `signOut()` with `Clerk.shared.signOut()`
- [ ] Implement `refreshTokenIfNeeded()` via `Clerk.shared.session?.getToken()`
- [ ] Map `Clerk.shared.user` to local `ClerkUser` struct
- [ ] Verify `Info.plist` has `CFBundleURLTypes` with `"odyssey"` scheme for Google OAuth
- [ ] Test full sign-in → sync → sign-out flow on device

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

**Details:** Data isolation relies solely on WHERE clauses in each query. One missing filter exposes all users.
**Work:**

- [ ] Explore Neon Postgres RLS policies
- [ ] Or: create a scoped query wrapper in Rust that auto-injects user_id filter
- [ ] Add integration tests verifying cross-user data isolation

### P1-4. Protect recovery key from clipboard sniffing

**Files:** `AccountView.swift:102`, `BackupPromptModal.swift:158`
**Details:** Raw AES-256 master key copied to `UIPasteboard.general` — readable by any foreground app, synced via Universal Clipboard.
**Work:**

- [ ] Set `UIPasteboard.general.setItems([...], options: [.expirationDate: Date().addingTimeInterval(60)])` for auto-expiry
- [ ] Warn user about clipboard risks
- [ ] Consider alternative export: QR code, file export, or password-derived key

### P1-5. Fix silent error swallowing in auth UI

**Files:** `SignInView.swift:23,29`, `BackupPromptModal.swift:96,102`
**Details:** Auth actions use `try?` — errors are silently discarded. `BackupPromptModal` has no error display at all.
**Work:**

- [ ] Replace `try?` with `do/catch` and set `authManager.error`
- [ ] Add error display to `BackupPromptModal` (match `SignInView` pattern)

### P1-6. Validate client timestamps server-side

**File:** `odyssey-server/src/routes/entries.rs`
**Details:** `createdAt` and `updatedAt` are accepted as arbitrary client strings. A client can set `updatedAt` to year 2099 to always "win" sync conflicts.
**Work:**

- [ ] Reject timestamps more than ±24h from server time
- [ ] Consider setting `updated_at` server-side on upsert (authoritative)

### P1-7. Add request body size limits and string length constraints

**File:** `odyssey-server/src/validation.rs`
**Details:** String fields (journal, gratitude, etc.) accept unlimited length. 100 entries × unbounded strings = potential memory issue.
**Work:**

- [ ] Add max length validation to text fields
- [ ] Add hex color regex validation to `feelingColorHex`

### P1-8. Guard force unwraps on App Group container URLs

**Files:** `DataContainer.swift:31-33,45-46`, `SharedDefaults.swift:7`
**Details:** Force unwraps on `containerURL(forSecurityApplicationGroupIdentifier:)!` — crash on misconfigured entitlements.
**Work:**

- [ ] Replace with `guard let` + graceful error / fallback to local-only storage

### P1-9. DataRetentionService needs user confirmation

**File:** `Odyssey/Services/Retention/DataRetentionService.swift:8-34`
**Details:** Silently deletes entries older than 1 year for non-account users. No warning, no undo.
**Work:**

- [ ] Add user confirmation before deletion
- [ ] Or: only run retention after explicit user consent in settings
- [ ] Add logging of what was deleted

---

## P2 — Medium (Should fix before v1.0 release)

### P2-1. Add `@MainActor` to remaining ViewModels

**Files:** `OnboardingViewModel.swift`, `InsightsViewModel.swift`, `JournalViewModel.swift`
**Details:** ViewModels using `@Observable` should be `@MainActor` for thread safety.

### P2-2. Add JWT issuer and audience validation

**File:** `odyssey-server/src/auth.rs`
**Work:** Add `iss` and `aud` claims validation to JWT verification.

### P2-3. Add `syncID` / server-side unique identifier to DailyEntry

**Files:** `DailyEntry.swift`, `SyncPayload.swift`, `SyncService.swift`
**Details:** Currently matched by `entryDate` only. No delta/incremental sync capability.

### P2-4. Add background sync trigger

**Files:** `OdysseyAppDelegate.swift`, `SyncService.swift`
**Details:** `needsSync = true` is set in background snapshot, but sync only runs on foreground. Entries can sit unsynced for days.

### P2-5. Fix TabView swipe bypass in onboarding

**File:** `OnboardingFlowView.swift:19-24`
**Details:** `.tabViewStyle(.page)` allows swiping past permission steps without granting permissions.

### P2-6. Disable buttons during loading states

**Files:** `BackupPromptModal.swift:93-103`, `SignInView.swift:20-31`, `AccountView.swift:19-35`
**Details:** Auth/sync buttons remain tappable during loading.

### P2-7. Add location permission callback handling in onboarding

**File:** `OnboardingViewModel.swift:60-63`
**Details:** Permission dialog overlaps next step.

### P2-8. Add timeout to LocationCaptureService

**File:** `Odyssey/Services/LocationCaptureService.swift:18-27`
**Details:** No timeout — if CLLocationManager is deallocated before callback, async call hangs forever.

### P2-9. Fix SwiftData store migration error handling

**File:** `DataContainer.swift:52-60`
**Details:** `try?` on file copy can silently lose all data during App Group migration.

### P2-10. Add `updated_at` trigger in database

**Details:** No auto-update trigger on Postgres. Direct SQL updates won't update `updated_at`, breaking sync cursor.

### P2-11. Encrypt SwiftData store at rest

**File:** `DataContainer.swift:17-24`
**Details:** SQLite store is plaintext. Readable on jailbroken device / forensic extraction.

### P2-12. Add copy confirmation for recovery key

**Files:** `AccountView.swift:101-103`, `BackupPromptModal.swift:157-159`
**Details:** No visual feedback (toast/haptic) on clipboard copy.

---

## P3 — Low (Polish / tech debt for future iterations)

### P3-1. Add structured logging to backend
Already partially done — Rust backend uses `tracing` with `tower_http::trace::TraceLayer`. Could add request IDs.

### P3-2. Add security headers to API
Missing `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`.

### P3-3. Add index on `sync_log.user_id`
CASCADE delete requires sequential scan of unindexed `sync_log`.

### P3-4. Populate `device_id` in sync log
`sync_log.device_id` column exists but is never written.

### P3-5. Extract shared `signInButton` component
Identical Apple/Google sign-in button implementations duplicated across views.

### P3-6. Use constants for UserDefaults keys
`"hasSeenBackupPrompt"` and `"hasCompletedOnboarding"` are raw strings.

### P3-7. Fix visual inconsistencies
- `AccountCard.swift` uses `Color.accentTeal` vs `BackupPromptModal` uses `Color.accentAmber` for same action
- `ProfileView.swift` Account section missing `.listRowBackground(Color.cardSurface)`

### P3-8. Fix accessibility issues
- `AccountCard.swift:109-117` — bullet points lack VoiceOver labels
- `SyncStatusBanner.swift` — no `accessibilityElement(children: .combine)`
- `OnboardingNavigationBar.swift` — hidden back button still focusable by VoiceOver

### P3-9. Clean up test suite
- Delete empty `OdysseyTests.swift` scaffold
- Fix `PhotoLibraryServiceTests` (assertions test nothing useful)
- Replace `try!` / force unwraps in `EncryptionServiceTests` with `XCTUnwrap`

### P3-10. Add key rotation mechanism
No way to rotate encryption key. Compromised key exposes all historical ciphertexts.

### P3-11. Add certificate pinning
`APIClient.swift` uses `URLSession.shared` with no certificate pinning.

### P3-12. Remove unused `email` column or populate it
`email` column in `users` table exists but is never written to.

### P3-13. Photos not included in cloud backup
`attachedPhotoData` and `autoPhotoIdentifiers` are local-only.

### P3-14. CSV export bypasses encryption
Export writes all PII to unencrypted temp file shared via `UIActivityViewController`.

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
│  │  (Clerk SDK  │    │  (journal    │    │  (account,    │  │
│  │   pending)   │    │   submit)    │    │   sync,       │  │
│  │              │    │              │    │   export)     │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                    │          │
│  ┌──────▼───────────────────▼────────────────────▼───────┐  │
│  │              AuthManager (@MainActor)                  │  │
│  │  signIn: pending  │  signOut: local  │  token: keychain│ │
│  └──────────────────────────┬────────────────────────────┘  │
│                             │                               │
│  ┌──────────────────────────▼────────────────────────────┐  │
│  │                    SyncService (@MainActor)            │  │
│  │  ┌────────────┐  ┌────────────┐  ┌─────────────────┐ │  │
│  │  │ Encryption │  │  APIClient │  │ Merge (LWW,     │ │  │
│  │  │ (AES-GCM,  │  │ (xcconfig  │  │ no conflict    │ │  │
│  │  │  partial)  │  │  URL)      │  │  resolution)   │ │  │
│  │  └────────────┘  └────────────┘  └─────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │   SwiftData    │  │  SharedDefaults │  │   Keychain   │  │
│  │  (unencrypted  │  │  (screen time)  │  │  (AES key +  │  │
│  │   at rest)     │  │                 │  │  auth token) │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                             │
                      ┌──────▼──────┐
                      │odyssey-server│  (Rust/Axum on Render)
                      │  - JWT auth  │
                      │  - Rate limit│
                      │  - CORS      │
                      │  - Batch     │
                      │    upsert    │
                      └──────┬──────┘
                             │
                      ┌──────▼──────┐
                      │   Neon DB   │
                      │  (Postgres) │
                      └─────────────┘
```
