import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { users } from "../db/schema";
import type { Env } from "../types";
import { createDb } from "../db/client";

const app = new Hono<{ Bindings: Env; Variables: { userId: string } }>();

// DELETE /account — Delete all user data (GDPR cascade delete)
app.delete("/", async (c) => {
  const userId = c.get("userId");
  const db = createDb(c.env.DATABASE_URL);

  // CASCADE on FK will delete entries, key_backups, sync_log
  await db.delete(users).where(eq(users.clerkUserId, userId));

  return c.json({ deleted: true });
});

export default app;
