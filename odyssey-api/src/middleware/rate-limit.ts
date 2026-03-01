import { Context, Next } from "hono";

// Simple in-memory rate limiter for Cloudflare Workers
// In production, consider using Cloudflare's Rate Limiting API or Durable Objects
const requestCounts = new Map<string, { count: number; resetAt: number }>();

const WINDOW_MS = 60_000; // 1 minute
const MAX_REQUESTS = 60; // 60 requests per minute per user

export async function rateLimitMiddleware(c: Context, next: Next) {
  const userId = c.get("userId") as string;
  if (!userId) {
    await next();
    return;
  }

  const now = Date.now();
  const record = requestCounts.get(userId);

  if (!record || now > record.resetAt) {
    requestCounts.set(userId, { count: 1, resetAt: now + WINDOW_MS });
    await next();
    return;
  }

  record.count++;

  if (record.count > MAX_REQUESTS) {
    return c.json({ error: "Rate limit exceeded" }, 429);
  }

  await next();
}
