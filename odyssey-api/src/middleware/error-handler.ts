import { Context } from "hono";

export function errorHandler(err: Error, c: Context) {
  console.error("Unhandled error:", err);

  if (err.message.includes("rate limit")) {
    return c.json({ error: "Rate limit exceeded" }, 429);
  }

  return c.json({ error: "Internal server error" }, 500);
}
