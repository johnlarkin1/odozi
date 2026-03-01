import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { encryptedKeyBackups, users } from "../db/schema";
import { keyBackupSchema } from "../utils/validation";
import type { Env } from "../types";
import { createDb } from "../db/client";

const app = new Hono<{ Bindings: Env; Variables: { userId: string } }>();

// PUT /key-backup — Store encrypted recovery key
app.put("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();

  const parsed = keyBackupSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation failed", details: parsed.error.flatten() }, 400);
  }

  const db = createDb(c.env.DATABASE_URL);

  // Ensure user exists
  await db
    .insert(users)
    .values({ clerkUserId: userId })
    .onConflictDoNothing();

  await db
    .insert(encryptedKeyBackups)
    .values({
      userId,
      encryptedKeyData: parsed.data.encryptedKeyData,
      keyDerivationSalt: parsed.data.keyDerivationSalt ?? null,
    })
    .onConflictDoUpdate({
      target: encryptedKeyBackups.userId,
      set: {
        encryptedKeyData: parsed.data.encryptedKeyData,
        keyDerivationSalt: parsed.data.keyDerivationSalt ?? null,
        updatedAt: new Date(),
      },
    });

  return c.json({ stored: true });
});

// GET /key-backup — Retrieve encrypted recovery key
app.get("/", async (c) => {
  const userId = c.get("userId");
  const db = createDb(c.env.DATABASE_URL);

  const result = await db
    .select()
    .from(encryptedKeyBackups)
    .where(eq(encryptedKeyBackups.userId, userId))
    .limit(1);

  if (result.length === 0) {
    return c.json({ error: "No key backup found" }, 404);
  }

  return c.json({
    encryptedKeyData: result[0].encryptedKeyData,
    keyDerivationSalt: result[0].keyDerivationSalt,
  });
});

export default app;
