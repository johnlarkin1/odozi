import { Context, Next } from "hono";

// Simple in-memory rate limiter for Cloudflare Workers
// Cloudflare provides L7 DDoS protection; this is best-effort per-isolate
const requestCounts = new Map<string, { count: number; resetAt: number }>();

const WINDOW_MS = 60_000; // 1 minute
const MAX_REQUESTS = 60; // 60 requests per minute per IP
const MAX_MAP_SIZE = 10_000;

function purgeExpired() {
  if (requestCounts.size <= MAX_MAP_SIZE) return;
  const now = Date.now();
  for (const [key, record] of requestCounts) {
    if (now > record.resetAt) {
      requestCounts.delete(key);
    }
  }
}

export async function rateLimitMiddleware(c: Context, next: Next) {
  // Use Cloudflare's connecting IP header, fall back to a generic key
  const key =
    c.req.header("cf-connecting-ip") ??
    c.req.header("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown";

  const now = Date.now();
  purgeExpired();

  const record = requestCounts.get(key);

  if (!record || now > record.resetAt) {
    requestCounts.set(key, { count: 1, resetAt: now + WINDOW_MS });
    await next();
    return;
  }

  record.count++;

  if (record.count > MAX_REQUESTS) {
    return c.json({ error: "Rate limit exceeded" }, 429);
  }

  await next();
}
