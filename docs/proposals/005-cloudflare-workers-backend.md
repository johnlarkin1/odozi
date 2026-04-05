---
title: Cloudflare Workers Backend Migration
status: archived
date: 2026-03-17
tags: [backend, infrastructure, cloudflare, workers, cost-optimization, neon, postgres]
---

# 005 — Cloudflare Workers Backend Migration

## Summary

Migrate the Odyssey API backend from a Rust/Axum server deployed on Render to Cloudflare Workers using the existing TypeScript/Hono implementation in `odyssey-api/`. Keep Neon Postgres as the database, add Hyperdrive for connection pooling, and leverage the Workers free tier to eliminate hosting costs entirely for our current scale.

## Motivation

### Cost

| | Current (Render Starter) | Proposed (CF Workers Free) | Proposed (CF Workers Paid) |
|---|---|---|---|
| **Monthly cost** | $7/mo | $0 | $5/mo |
| **Cold starts** | ~60s on free; none on Starter | None (V8 isolates) | None |
| **Edge locations** | 1 region | 310+ global PoPs | 310+ global PoPs |
| **Spin-down** | Yes (free tier) | Never | Never |
| **Request limit** | Unlimited | 100K/day (~3M/month) | 10M/month |

Render's free tier spins down after 15 minutes of inactivity, causing ~60-second cold starts — unacceptable for a mobile app backend. The Starter plan ($7/mo) fixes this but runs in a single region. Cloudflare Workers never sleep, deploy globally, and the free tier supports 100K requests/day — more than enough for Odyssey's current and near-future user base.

### Performance

Workers run at 310+ edge locations worldwide. A user in Tokyo hits a PoP in Tokyo, not a single Render server in Oregon. While the Neon database is still in one region, Hyperdrive's connection pooling and query caching significantly reduce the latency penalty.

### Operational Simplicity

- No Docker builds or container management
- No server provisioning, scaling, or health monitoring
- Deploys in <5 seconds via `wrangler deploy`
- Automatic HTTPS, DDoS protection, and global routing

### Existing Work

We already have a partial Hono/Workers implementation in `odyssey-api/` with identical API contracts to the Rust backend. This is not a greenfield rewrite — it's completing and hardening existing work.

## Current State of `odyssey-api/`

The TypeScript implementation already covers:

| Component | Status | Notes |
|---|---|---|
| Hono app scaffold | Done | `src/index.ts` |
| Drizzle ORM schema | Done | `src/db/schema.ts` — matches Rust models exactly |
| Neon serverless driver | Done | `src/db/client.ts` — should migrate to Hyperdrive |
| POST /entries (batch upsert) | Done | `src/routes/entries.ts` |
| GET /entries (cursor pagination) | Done | `src/routes/entries.ts` |
| DELETE /entries/:date | Done | `src/routes/entries.ts` |
| DELETE /account | Done | `src/routes/account.ts` |
| PUT /key-backup | Done | `src/routes/key_backup.ts` |
| GET /key-backup | Done | `src/routes/key_backup.ts` |
| Clerk JWT auth middleware | Done | `src/auth/clerk.ts` + `src/auth/middleware.ts` |
| Rate limiting middleware | Done | `src/middleware/rate-limit.ts` — in-memory, per-user |
| CORS | Done | Global Hono middleware |
| wrangler.toml | Done | Basic config present |
| Input validation (Zod) | Partial | Needs parity with Rust's `validation.rs` |
| Security headers | Missing | X-Frame-Options, HSTS, X-Content-Type-Options |
| Health endpoint | Done | GET /health |
| Load test support | Missing | RSA bypass mode from Rust backend |
| Hyperdrive integration | Missing | Currently uses Neon HTTP driver directly |

## Technical Approach

### 1. Upgrade Database Connection to Hyperdrive

Replace the Neon serverless HTTP driver with Hyperdrive + `node-postgres` for persistent connection pooling.

**Current (`odyssey-api/src/db/client.ts`):**
```typescript
import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";

export function createDb(databaseUrl: string) {
  const sql = neon(databaseUrl);
  return drizzle(sql);
}
```

**Proposed:**
```typescript
import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";

export function createDb(hyperdrive: Hyperdrive) {
  const pool = new pg.Pool({
    connectionString: hyperdrive.connectionString,
  });
  return drizzle(pool);
}
```

**wrangler.toml addition:**
```toml
[[hyperdrive]]
binding = "HYPERDRIVE"
id = "<hyperdrive-config-id>"
```

**Setup command:**
```bash
npx wrangler hyperdrive create odyssey-db \
  --connection-string="postgres://user:pass@ep-xyz.us-east-2.aws.neon.tech/odyssey?sslmode=require"
```

Hyperdrive is included on both free and paid Workers plans at no extra cost.

### 2. Add Input Validation Parity

The Rust backend's `validation.rs` enforces strict constraints that the TypeScript implementation must match:

```typescript
// src/validation/entry.ts
import { z } from "zod";

export const entrySchema = z.object({
  entryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  journalEntry: z.string().max(20_480).optional(),     // 20 KB
  gratitude: z.string().max(20_480).optional(),
  win: z.string().max(20_480).optional(),
  tension: z.string().max(20_480).optional(),
  singleWordFeeling: z.string().max(1_024).optional(),  // 1 KB
  latitude: z.string().max(1_024).optional(),
  longitude: z.string().max(1_024).optional(),
  city: z.string().max(1_024).optional(),
  state: z.string().max(1_024).optional(),
  country: z.string().max(1_024).optional(),
  feeling: z.number().int().min(1).max(10).optional(),
  sleepQuality: z.number().int().min(1).max(10).optional(),
  feelingColorHex: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  drinks: z.number().int().min(0).optional(),
  stepCount: z.number().min(0).optional(),
  walkingDistanceMeters: z.number().min(0).optional(),
  sleepHours: z.number().min(0).optional(),
  screenTimeSeconds: z.number().min(0).optional(),
  pickups: z.number().min(0).optional(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

// Timestamp drift validation (±48 hours)
export function validateTimestamp(ts: string): boolean {
  const diff = Math.abs(Date.now() - new Date(ts).getTime());
  return diff <= 48 * 60 * 60 * 1000;
}

// Entry date range validation (±1 day future, ±2 years past)
export function validateEntryDateRange(date: string): boolean {
  const d = new Date(date);
  const now = new Date();
  const oneDayFuture = new Date(now);
  oneDayFuture.setDate(oneDayFuture.getDate() + 1);
  const twoYearsPast = new Date(now);
  twoYearsPast.setFullYear(twoYearsPast.getFullYear() - 2);
  return d <= oneDayFuture && d >= twoYearsPast;
}
```

### 3. Add Security Headers Middleware

```typescript
// src/middleware/security-headers.ts
import { createMiddleware } from "hono/factory";

export const securityHeaders = createMiddleware(async (c, next) => {
  await next();
  c.header("X-Content-Type-Options", "nosniff");
  c.header("X-Frame-Options", "DENY");
  c.header("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
});
```

### 4. Improve Rate Limiting

The current in-memory rate limiter resets on every deploy and doesn't work across Workers isolates. Two options:

**Option A — Cloudflare Rate Limiting Rules (recommended for free tier):**
Configure via Cloudflare dashboard or API. No code needed. Limits apply globally across all edge locations.

**Option B — Workers KV-backed rate limiter:**
```typescript
// Slightly more latency, but distributed and persistent
export async function checkRateLimit(
  kv: KVNamespace,
  key: string,
  limit: number,
  windowSecs: number
): Promise<boolean> {
  const now = Math.floor(Date.now() / 1000);
  const windowKey = `rl:${key}:${Math.floor(now / windowSecs)}`;
  const count = parseInt((await kv.get(windowKey)) || "0");
  if (count >= limit) return false;
  await kv.put(windowKey, String(count + 1), { expirationTtl: windowSecs * 2 });
  return true;
}
```

Note: KV has eventual consistency, so this is best-effort. For strict rate limiting, use Cloudflare's built-in rate limiting rules.

### 5. Cron Triggers for Scheduled Tasks

The Rust backend registers background tasks via `BGTaskScheduler`. Any server-side scheduled work (like future weekly digest email triggers) can use Workers Cron Triggers:

```toml
# wrangler.toml
[triggers]
crons = ["0 2 * * *"]  # Daily at 2 AM UTC
```

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env) {
    return app.fetch(request, env);
  },
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    // Future: weekly digest processing, data cleanup, etc.
    console.log(`Cron triggered: ${event.cron}`);
  },
};
```

Free tier cron CPU limit is 50ms — sufficient for triggering lightweight tasks. For heavier processing, upgrade to the $5/mo paid plan (30s CPU per cron invocation).

### 6. Updated `wrangler.toml`

```toml
name = "odyssey-api"
main = "src/index.ts"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]

[vars]
CLERK_JWKS_URL = "https://YOUR_CLERK_DOMAIN/.well-known/jwks.json"
ENVIRONMENT = "production"

# Secrets (set via `wrangler secret put`):
# - CLERK_PUBLISHABLE_KEY

[[hyperdrive]]
binding = "HYPERDRIVE"
id = "<hyperdrive-config-id>"

# Optional: KV namespace for rate limiting / caching
# [[kv_namespaces]]
# binding = "CACHE"
# id = "<kv-namespace-id>"

# Optional: Cron triggers
# [triggers]
# crons = ["0 2 * * *"]
```

## Migration Plan

### Phase 1: Harden `odyssey-api/` (1-2 days)

1. Add Hyperdrive integration (replace Neon HTTP driver)
2. Port all validation rules from `validation.rs` to Zod schemas
3. Add security headers middleware
4. Add `/healthz` endpoint (matching Rust convention)
5. Write integration tests against a Neon dev database

### Phase 2: Parallel Deployment (1 day)

1. Deploy Workers backend to a staging URL (e.g., `odyssey-api-staging.workers.dev`)
2. Run the existing Locust load tests against it
3. Verify API contract parity by running both backends against the same test suite
4. Manually test from the iOS app by swapping `ODYSSEY_API_BASE_URL`

### Phase 3: Traffic Cutover (1 day)

1. Update `ODYSSEY_API_BASE_URL` in the iOS app config to point to the Workers URL
2. Optionally put a custom domain on the Worker (e.g., `api.odozi.app`)
3. Monitor via Workers Analytics dashboard (built-in, free)
4. Keep Render deployment warm for 1-2 weeks as a rollback option

### Phase 4: Cleanup (after stable)

1. Remove `odyssey-server/` (Rust backend) from the repo
2. Remove Render deployment
3. Update CI/CD to deploy via `wrangler deploy`
4. Update CLAUDE.md and project docs

## Trade-offs & Constraints

### Advantages

- **Zero cost** at current scale (free tier: 100K req/day, no cold starts)
- **Global edge deployment** — lower latency for users worldwide
- **No infrastructure management** — no Docker, no server, no scaling config
- **Sub-second deploys** via `wrangler deploy`
- **Built-in DDoS protection** from Cloudflare's network
- **Existing implementation** — `odyssey-api/` already covers all routes

### Limitations

- **10ms CPU per request (free tier):** Sufficient for CRUD + JWT verification. If we add compute-heavy features (e.g., server-side analytics), we'd need the $5/mo paid plan (30s CPU).
- **In-memory rate limiting doesn't persist across isolates:** Use Cloudflare's built-in rate limiting rules or KV-backed counters instead.
- **128 MB memory per isolate:** Not a concern for our CRUD workload.
- **1 MB script size (free tier):** Hono + Drizzle + dependencies should fit comfortably. If it grows, the paid tier allows 10 MB.
- **No long-running connections:** Workers are request/response only. If we ever need WebSockets (e.g., real-time sync), we'd need Durable Objects (paid plan).
- **Neon is still single-region:** Hyperdrive's connection pooling and caching help, but true database reads still go to one region. This is unchanged from Render.
- **Vendor lock-in:** Hono is portable (runs on Deno, Bun, Node.js), but Hyperdrive and KV bindings are Cloudflare-specific. The core app logic remains portable.

### Why Not Rust on Workers?

Cloudflare supports Rust via `workers-rs` (compiles to WASM), but:
- Many Rust crates don't compile to `wasm32-unknown-unknown` (e.g., `tokio`, `sqlx`)
- WASM bundles easily exceed the 1 MB free tier limit
- For a CRUD API, the performance difference between Rust and TypeScript is negligible — nearly all time is spent waiting on Postgres
- TypeScript has better ecosystem support on Workers (Hono, Drizzle, `jose`, etc.)

## Open Questions

1. **Custom domain:** Should we put the Worker on `api.odozi.app` via Cloudflare DNS, or keep `odyssey-api.workers.dev`? Custom domain gives us flexibility to move later without app updates.

2. **Rate limiting strategy:** Cloudflare dashboard rules vs. KV-backed vs. accept the in-memory limitation? Dashboard rules are simplest but less flexible.

3. **Monitoring/alerting:** Workers Analytics is built-in, but should we add a lightweight error tracking service (e.g., Sentry's free tier) for production visibility?

4. **Load test infrastructure:** Port the Locust load tests to hit the Workers endpoint? The RSA bypass mode in the Rust backend would need to be replicated.

5. **Staging environment:** Use a separate Worker (`odyssey-api-staging`) or Workers environments (preview deployments)?

## Next Steps

1. **Set up Hyperdrive** — Create a Hyperdrive config pointing to our Neon database
2. **Port validation rules** — Audit `odyssey-server/src/validation.rs` and replicate in Zod
3. **Add security headers** — Simple middleware addition
4. **Deploy to staging** — `wrangler deploy --env staging`
5. **Run load tests** — Verify performance and correctness under load
6. **iOS app testing** — Swap base URL, test full sync flow on a physical device
7. **Cut over** — Update production config, monitor, decommission Render
