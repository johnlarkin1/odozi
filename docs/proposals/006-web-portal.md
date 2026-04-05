---
title: Web Portal — View-Only Journal Dashboard
status: archived
date: 2026-03-19
tags: [web, portal, next.js, clerk, dashboard, cross-platform]
---

# 006 — Web Portal — View-Only Journal Dashboard

## Summary

Add an authenticated web portal at `app.odozi.app` where signed-in users can browse their journal entries, view mood trends, and explore insights — but **not** create or edit entries. Data entry remains exclusive to native clients (iOS, macOS, Apple Watch) where passive data capture (HealthKit, location, Screen Time) and the guided prompt UX work best. The portal reuses the existing Cloudflare Workers API, Clerk authentication, and Neon Postgres database — no new backend services required.

## Motivation

### Why a Web Portal?

1. **Desktop review sessions.** Users who journal on their phone often want to review patterns, re-read old entries, or browse insights on a large screen at their desk. A full web dashboard is better for this than the compact iOS Insights tab.

2. **Platform reach.** Not every potential user has an iPhone immediately available. A web portal lets someone explore their data from any browser — a work laptop, a Chromebook, a shared family computer — without installing native software.

3. **Onboarding hook.** A "View your data online" CTA after sign-up gives users a reason to create a Clerk account, which unlocks cloud sync. Today, many users may skip account creation because it's not required for local-only journaling.

4. **Partner/therapist sharing.** A view-only web link (future: shareable read-only URLs) lets users show their mood patterns to a therapist or partner without handing over their phone.

### Why View-Only?

- **Passive data can't be captured on the web.** Location, HealthKit, Screen Time — three of the eight background data streams — are unavailable in a browser. Entries created on web would be permanently incomplete.
- **Guided prompt UX is mobile-native.** The swipe-through, skip-enabled, 8-step prompt flow is designed for touch. Rebuilding it as a web form would be a worse experience and fragment the codebase.
- **Simpler scope.** View-only means no write endpoints, no merge conflicts, no real-time sync contention. We ship faster and with fewer edge cases.
- **Clear value prop.** "Journal on your phone, reflect on any screen" is a crisp, understandable product boundary.

## Current Infrastructure

### What Already Exists

| Component | Status | Notes |
|-----------|--------|-------|
| **Cloudflare Workers API** (`odyssey-api/`) | Functional | Hono + Drizzle + Neon Postgres. `GET /entries` with cursor pagination already serves everything the portal needs. |
| **Clerk authentication** | Functional | iOS app uses Clerk SDK with Apple/Google/GitHub OAuth. Same Clerk app instance works for web via `@clerk/nextjs`. |
| **Database schema** | Complete | `entries` table has all fields. Encrypted text fields (journal, gratitude, win, tension) are base64 AES-256-GCM ciphertext. Plaintext metrics (feeling, sleep_quality, steps, etc.) are queryable. |
| **Marketing website** (`website/`) | Live | Next.js 15, React 19, Tailwind 4, static export to `odozi.app`. Currently marketing-only, no auth. |
| **Encryption** | Client-side | Sensitive text encrypted with AES-256-GCM before upload. Key stored in iOS Keychain, not synced to iCloud. Web portal needs key access to decrypt entries. |

### Key Gap: Encryption Key Access

The encryption master key lives in the iOS Keychain (`com.johnlarkin.Odyssey.encryption`). The web portal needs this key to decrypt journal text. Two paths:

1. **Key backup endpoint** — Already exists: `PUT /key-backup` and `GET /key-backup` in the API. The iOS app can upload an encrypted copy of the master key (encrypted with a user-chosen passphrase). The web portal prompts for the passphrase on first login to derive the key.

2. **Plaintext-only mode** — The portal shows only plaintext metrics (mood score, sleep quality, steps, drinks, feeling color) and omits encrypted fields. This is a viable MVP — mood trends, streaks, maps, and sleep charts all work without decryption.

**Recommendation:** Ship plaintext-only mode first (Phase 1), add key import in Phase 2.

## Technical Approach

### Architecture Overview

```
┌─────────────────────────────────────────────┐
│  app.odozi.app (Next.js 15, SSR)            │
│                                              │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐ │
│  │  Clerk    │  │ Dashboard │  │ Insights │ │
│  │  Auth     │  │  (entries │  │ (charts, │ │
│  │  Provider │  │   list)   │  │  map)    │ │
│  └──────────┘  └───────────┘  └──────────┘ │
│        │              │              │       │
│        ▼              ▼              ▼       │
│  ┌──────────────────────────────────────┐   │
│  │   API Client (fetch + Clerk JWT)     │   │
│  └──────────────────────────────────────┘   │
└────────────────┬────────────────────────────┘
                 │ HTTPS
                 ▼
┌──────────────────────────────────────────────┐
│  api.odozi.app (Cloudflare Workers / Hono)   │
│  GET /entries, GET /key-backup               │
│  Clerk JWT validation middleware             │
└────────────────┬─────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────┐
│  Neon Postgres (via Hyperdrive)              │
│  entries, users, encrypted_key_backups       │
└──────────────────────────────────────────────┘
```

### Phase 1: Plaintext Metrics Dashboard (MVP)

**Estimated scope:** ~2-3 weeks

#### 1.1 — Separate the Portal from the Marketing Site

The marketing site (`website/`) currently uses `output: "export"` for static hosting. A portal with auth needs SSR.

**Option A (recommended): Separate Next.js app**

Create `portal/` alongside `website/`. This keeps the marketing site fast and static, and lets the portal use SSR + Clerk middleware independently.

```
odyssey-2/
├── website/          # Marketing site (static export, odozi.app)
├── portal/           # User portal (SSR, app.odozi.app)
├── odyssey-api/      # Backend API (api.odozi.app)
└── ...
```

- Deploy portal to Cloudflare Pages (free tier: unlimited sites, 500 builds/month) or Vercel
- Custom domain: `app.odozi.app`
- Reuse shared design tokens (Tailwind config, color palette) via a shared `packages/design-tokens/` workspace

**Option B: Subdirectory in marketing site**

Convert the marketing site from static export to hybrid (SSR for `/app/*`, static for everything else). Simpler repo structure but couples marketing deploys with portal deploys.

**Recommendation:** Option A. The marketing site should stay fast and simple.

#### 1.2 — Clerk Integration for Web

Install `@clerk/nextjs` in the portal app:

```typescript
// portal/src/app/layout.tsx
import { ClerkProvider } from "@clerk/nextjs";

export default function RootLayout({ children }) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body className="dark bg-gray-950 text-white">{children}</body>
      </html>
    </ClerkProvider>
  );
}
```

Protect all routes via Clerk middleware:

```typescript
// portal/src/middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher(["/sign-in(.*)", "/sign-up(.*)"]);

export default clerkMiddleware(async (auth, request) => {
  if (!isPublicRoute(request)) {
    await auth.protect();
  }
});
```

Clerk supports the same OAuth strategies the iOS app uses (Apple, Google, GitHub). Users sign in with the same account they use on iOS — the Clerk user ID ties everything together.

#### 1.3 — API Client

Create a typed client that fetches from the existing Workers API:

```typescript
// portal/src/lib/api-client.ts
import { auth } from "@clerk/nextjs/server";

const API_BASE = process.env.NEXT_PUBLIC_API_URL; // https://api.odozi.app

interface Entry {
  entryDate: string;
  feeling: number;
  sleepQuality: number;
  feelingColorHex: string;
  drinks: number;
  stepCount: number | null;
  walkingDistanceMeters: number | null;
  sleepHours: number | null;
  screenTimeSeconds: number | null;
  pickups: number | null;
  // Encrypted fields (Phase 2):
  // journalEntry, gratitude, win, tension, singleWordFeeling
  // latitude, longitude, city, state, country
  createdAt: string;
  updatedAt: string;
}

interface EntriesResponse {
  entries: Entry[];
  cursor: string | null;
}

export async function fetchEntries(
  since?: string,
  cursor?: string,
  limit = 200
): Promise<EntriesResponse> {
  const { getToken } = await auth();
  const token = await getToken();

  const params = new URLSearchParams({ limit: String(limit) });
  if (since) params.set("since", since);
  if (cursor) params.set("cursor", cursor);

  const res = await fetch(`${API_BASE}/entries?${params}`, {
    headers: { Authorization: `Bearer ${token}` },
    next: { revalidate: 60 }, // ISR: refresh every 60s
  });

  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
```

#### 1.4 — Portal Pages

| Route | View | Data Source |
|-------|------|-------------|
| `/` | Dashboard overview | Last 30 days of entries |
| `/entries` | Scrollable entry list with calendar | All entries, paginated |
| `/entries/[date]` | Entry detail (plaintext fields only in Phase 1) | Single entry |
| `/insights` | Mood trend chart, streak tracker, sleep chart | All entries |
| `/insights/map` | Map with mood-colored pins | Entries with lat/lon (encrypted in Phase 1 — skip or use plaintext metrics as proxy) |
| `/settings` | Account info, encryption key import (Phase 2) | Clerk user profile |

#### 1.5 — Visualization Libraries

The iOS app uses Swift Charts and MapKit. The web portal needs JavaScript equivalents:

| iOS Component | Web Equivalent | Library |
|---------------|----------------|---------|
| Swift Charts (mood trends) | Line/area charts | **Recharts** (React-native, lightweight) or **Chart.js** via react-chartjs-2 |
| Swift Charts (streak bars) | Bar charts | Recharts |
| MapKit (mood pins) | Interactive map | **Mapbox GL JS** (free tier: 50K loads/mo) or **Leaflet** + OpenStreetMap (fully free) |
| Custom FlowLayout (word cloud) | CSS/SVG word cloud | **react-wordcloud** or custom CSS grid |
| Swift Charts (year-in-review sparklines) | Sparkline charts | Recharts (tiny area chart variant) |

**Design tokens mapping** (from `Color+Extensions.swift`):

```typescript
// portal/src/lib/design-tokens.ts
export const colors = {
  accentAmber: "#F5A623",   // Primary accent
  accentTeal: "#4ECDC4",    // Secondary accent
  successGreen: "#7ED957",  // Positive indicators
  coralRed: "#FF6B6B",      // Alerts, tension
  cardSurface: "#1C1C1E",   // Card backgrounds
  background: "#000000",    // App background
} as const;

// Mood color scale (matches iOS MoodColor mapping)
export const moodColors: Record<number, string> = {
  1: "#8B0000",  // Deep red
  2: "#CC3333",
  3: "#E06040",
  4: "#CC8844",
  5: "#CCAA44",  // Neutral yellow
  6: "#88AA44",
  7: "#44AA55",
  8: "#33AA77",
  9: "#2299AA",
  10: "#1E90FF", // Bright blue
};
```

#### 1.6 — Dashboard Layout

```
┌──────────────────────────────────────────────────────────┐
│  🌙 Odyssey                          John  ▾  │ Sign Out │
├──────────┬───────────────────────────────────────────────┤
│          │                                               │
│ Overview │  ┌─ Mood This Month ──────────────────────┐  │
│ Entries  │  │  📈 Line chart with daily mood scores  │  │
│ Insights │  │     Color-coded by feeling hex         │  │
│ Settings │  └────────────────────────────────────────┘  │
│          │                                               │
│          │  ┌─ Quick Stats ──────┐ ┌─ Current Streak ─┐ │
│          │  │ Avg Mood: 7.2      │ │ 🔥 14 days       │ │
│          │  │ Entries: 89        │ │ Best: 42 days     │ │
│          │  │ Avg Sleep: 7.1h    │ │                   │ │
│          │  └────────────────────┘ └───────────────────┘ │
│          │                                               │
│          │  ┌─ Recent Entries ────────────────────────┐  │
│          │  │ Mar 19 · 😊 8/10 · "grateful" · 8,421… │  │
│          │  │ Mar 18 · 😌 7/10 · "calm"     · 6,102… │  │
│          │  │ Mar 17 · 😤 4/10 · "stressed"  · 3,88… │  │
│          │  └────────────────────────────────────────┘  │
└──────────┴───────────────────────────────────────────────┘
```

Dark theme enforced, matching the iOS app's aesthetic.

### Phase 2: Encrypted Field Access

**Estimated scope:** ~1-2 weeks (after Phase 1)

#### 2.1 — Key Import Flow

When a user first visits the portal, they won't have access to encrypted fields. The unlock flow:

1. Portal detects entries exist but encrypted fields are opaque → shows "Unlock your journal" banner
2. User opens iOS app → Settings → "Export Recovery Key" → copies base64 key or scans QR
3. On portal: user pastes recovery key or enters passphrase (if key-backup endpoint is used)
4. Portal derives the AES-256-GCM key, stores it in browser:
   - **Option A:** `sessionStorage` (cleared on tab close — most secure)
   - **Option B:** Browser `SubtleCrypto` wrapped key in `IndexedDB` (persists across sessions, encrypted with a PIN)
5. Client-side JavaScript decrypts entries using Web Crypto API:

```typescript
// portal/src/lib/crypto.ts
async function decryptField(
  ciphertext: string, // base64 encoded
  key: CryptoKey
): Promise<string> {
  const data = Uint8Array.from(atob(ciphertext), (c) => c.charCodeAt(0));
  // AES-256-GCM: first 12 bytes = IV, rest = ciphertext + tag
  const iv = data.slice(0, 12);
  const encrypted = data.slice(12);

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    encrypted
  );

  return new TextDecoder().decode(decrypted);
}
```

#### 2.2 — Unlocked Entry Detail

Once decrypted, the entry detail page shows:

- Full journal text (formatted markdown)
- Gratitude, Win, Tension sections
- Single-word feeling with color badge
- Location name (city, state) + map pin
- All plaintext metrics (mood, sleep, steps, drinks, screen time)

#### 2.3 — Privacy Safeguards

- **No server-side decryption.** The API never has the key. All decryption happens in the browser.
- **Session timeout.** Auto-lock after 15 minutes of inactivity (clear key from memory).
- **No caching of decrypted content.** Decrypted text is held in React state only, never written to localStorage/IndexedDB.
- **CSP headers.** Strict Content-Security-Policy to prevent XSS exfiltration of the key.

### Phase 3: Enhanced Insights

**Estimated scope:** ~2-3 weeks (after Phase 2)

#### 3.1 — Mood Map

Interactive map showing entries with location data (requires Phase 2 for decrypted lat/lon):

- Mapbox GL JS or Leaflet with custom mood-colored markers
- Click a pin to see the entry detail in a sidebar
- Filter by date range, mood score, or feeling word

#### 3.2 — Year-in-Review Web Version

Recreate the iOS Year-in-Review cards as a scrollable web experience:

- Total entries, mood average, streak records
- Monthly mood heatmap
- Top feeling words (word cloud)
- "Wrapped-style" shareable cards (use `html2canvas` for image export)

#### 3.3 — Export & Reports

- **CSV export** — Already available on iOS (`ProfileView`); add web equivalent
- **PDF report** — Generate monthly/yearly PDF summaries using `@react-pdf/renderer`
- **Printable view** — Clean, ink-friendly layout for therapist appointments

### Phase 4: Sharing & Collaboration (Future)

- **Read-only share links** — Generate a time-limited, passphrase-protected URL that lets someone view a date range of entries (plaintext metrics only, no journal text)
- **Therapist portal** — Separate role with access to shared entries only
- **Family dashboard** — Aggregate mood trends across family members (with consent)

## Integration Points

| Existing Component | How Portal Uses It |
|---|---|
| `odyssey-api/src/routes/entries.ts` | `GET /entries` — primary data source, no changes needed |
| `odyssey-api/src/routes/key_backup.ts` | `GET /key-backup` — retrieve encrypted key for browser decryption |
| `odyssey-api/src/auth/middleware.ts` | Clerk JWT validation — works for web tokens too (same Clerk app) |
| `odyssey-api/src/db/schema.ts` | Database schema — read-only access, no migrations needed |
| `website/src/components/Header.tsx` | Shared marketing header — add "Open App" / "Sign In" CTA |
| `Odyssey/Services/Encryption/EncryptionService.swift` | AES-256-GCM format must match Web Crypto API implementation exactly |
| `Odyssey/Services/Auth/AuthManager.swift` | Same Clerk user ID ties iOS and web sessions together |

### New API Endpoints Needed

The existing API is sufficient for Phase 1-2. For Phase 3+, consider:

| Endpoint | Purpose | Phase |
|----------|---------|-------|
| `GET /entries/stats` | Aggregated stats (total entries, avg mood, streak) to avoid fetching all entries for dashboard | Phase 1 |
| `GET /entries/monthly/:year/:month` | Month-scoped fetch for calendar views | Phase 1 |
| `GET /entries/insights` | Pre-computed insights (mood trends, top words) for fast dashboard load | Phase 3 |
| `POST /share-links` | Generate time-limited read-only share URLs | Phase 4 |

## Trade-offs & Constraints

### Advantages

- **No new backend.** Reuses existing Cloudflare Workers API and Neon Postgres.
- **Clerk handles auth.** Same user database, same OAuth strategies, zero custom auth code.
- **View-only = safe.** No write path means no sync conflicts, no data loss risk, no merge logic.
- **Progressive enhancement.** Phase 1 (plaintext only) ships fast and is useful immediately.

### Constraints

- **Encryption key distribution.** Users must manually export their key from iOS and import into the browser. This is friction, but it preserves the zero-knowledge guarantee. We should never send the raw key through our servers.
- **No offline support.** The portal requires internet access (unlike the iOS app which works fully offline). This is acceptable for a "reflection on a big screen" use case.
- **No real-time sync.** Entries synced from iOS appear on the portal after the next foreground sync (typically within minutes). There's no push notification to the browser when new entries land.
- **Map requires decryption.** Location data is encrypted. The mood map is unavailable in Phase 1 unless we add plaintext approximate location (city-level) to the database schema — worth considering.
- **Static export incompatible.** The marketing site uses `output: "export"`. The portal needs SSR for Clerk middleware. Hence the separate app recommendation.

### Privacy & Security

| Concern | Mitigation |
|---------|------------|
| XSS could exfiltrate encryption key | Strict CSP headers, no inline scripts, key held in `sessionStorage` only |
| Session hijacking | Clerk handles session tokens with HttpOnly cookies, CSRF protection |
| Data at rest in browser | No persistent storage of decrypted content; key cleared on session end |
| GDPR compliance | `DELETE /account` cascade-deletes all server data; portal respects this |
| Third-party analytics | Minimal tracking; no sending journal content to analytics services |

## Hosting & Deployment

| Service | Purpose | Cost |
|---------|---------|------|
| **Cloudflare Pages** | Portal hosting (SSR via Workers) | Free (unlimited sites, 500 builds/mo) |
| **Clerk** | Authentication | Free up to 10K MAU |
| **Neon Postgres** | Database (already exists) | Free tier (0.5 GB) |
| **Cloudflare Workers** | API (already exists) | Free tier (100K req/day) |
| **Mapbox** (Phase 3) | Map tiles | Free up to 50K loads/mo |
| **Total incremental cost** | | **$0** at current scale |

## Open Questions

1. **Subdomain strategy.** `app.odozi.app` vs `portal.odozi.app` vs `odozi.app/app`? Recommendation: `app.odozi.app` — clean, obvious, cookie-isolated from marketing site.

2. **Plaintext city-level location.** Should we add an unencrypted `city` field to the database to enable the map in Phase 1 without decryption? This leaks some location data to the server but dramatically simplifies the MVP.

3. **Key backup UX.** The current key-backup API encrypts the key with a user passphrase. Should the web portal use this (requires user to remember a passphrase), or should we offer QR code scanning from iOS → web camera?

4. **Mobile portal.** Should `app.odozi.app` be responsive for mobile browsers, or should we redirect mobile users to the native app? Recommendation: responsive, but show a "Better on the app" banner.

5. **Notification when new entries sync.** Should the portal poll for new entries, use WebSockets, or just refresh on page load? Recommendation: refresh on page load + manual refresh button. Real-time is over-engineered for view-only.

6. **Data retention on web.** Should the portal respect the 1-year auto-delete policy from `DataRetentionService`, or should the server be the authority? Recommendation: server-side retention is authoritative; portal shows whatever the API returns.

## Next Steps

1. **Create `portal/` Next.js app** with Clerk integration and dark theme
2. **Wire up API client** to `GET /entries` with Clerk JWT
3. **Build dashboard page** with mood trend chart (Recharts) and streak counter
4. **Build entries list** with calendar picker and entry detail (plaintext fields)
5. **Add `GET /entries/stats` endpoint** to Workers API for dashboard summary
6. **Deploy to Cloudflare Pages** at `app.odozi.app`
7. **Add "View on Web" CTA** to iOS app's Profile tab and marketing site header
8. **Phase 2:** Implement browser-side AES-256-GCM decryption + key import flow
9. **Phase 3:** Add mood map, year-in-review, and export features
