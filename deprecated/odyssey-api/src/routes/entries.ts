import { Hono } from "hono";
import { eq, and, gt } from "drizzle-orm";
import { entries, users, syncLog } from "../db/schema";
import { syncUploadSchema, validateSyncEntry } from "../utils/validation";
import type { Env } from "../types";
import { createDb } from "../db/client";

const app = new Hono<{ Bindings: Env; Variables: { userId: string } }>();

// POST /entries — Batch upsert entries
app.post("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();

  const parsed = syncUploadSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Validation failed", details: parsed.error.flatten() }, 400);
  }

  const db = createDb(c.env.DATABASE_URL);

  // Ensure user exists (upsert)
  await db
    .insert(users)
    .values({ clerkUserId: userId })
    .onConflictDoUpdate({
      target: users.clerkUserId,
      set: { lastSyncAt: new Date() },
    });

  const syncedAt = new Date().toISOString();
  let upsertedCount = 0;

  for (const entry of parsed.data.entries) {
    validateSyncEntry(entry);

    await db
      .insert(entries)
      .values({
        userId,
        entryDate: entry.entryDate,
        journalEntry: entry.journalEntry ?? null,
        gratitude: entry.gratitude ?? null,
        win: entry.win ?? null,
        tension: entry.tension ?? null,
        singleWordFeeling: entry.singleWordFeeling ?? null,
        latitude: entry.latitude ?? null,
        longitude: entry.longitude ?? null,
        city: entry.city ?? null,
        state: entry.state ?? null,
        country: entry.country ?? null,
        feeling: entry.feeling,
        sleepQuality: entry.sleepQuality,
        feelingColorHex: entry.feelingColorHex,
        drinks: entry.drinks,
        stepCount: entry.stepCount ?? null,
        walkingDistanceMeters: entry.walkingDistanceMeters ?? null,
        sleepHours: entry.sleepHours ?? null,
        screenTimeSeconds: entry.screenTimeSeconds ?? null,
        pickups: entry.pickups ?? null,
        createdAt: new Date(entry.createdAt),
        updatedAt: new Date(entry.updatedAt),
      })
      .onConflictDoUpdate({
        target: [entries.userId, entries.entryDate],
        set: {
          journalEntry: entry.journalEntry ?? null,
          gratitude: entry.gratitude ?? null,
          win: entry.win ?? null,
          tension: entry.tension ?? null,
          singleWordFeeling: entry.singleWordFeeling ?? null,
          latitude: entry.latitude ?? null,
          longitude: entry.longitude ?? null,
          city: entry.city ?? null,
          state: entry.state ?? null,
          country: entry.country ?? null,
          feeling: entry.feeling,
          sleepQuality: entry.sleepQuality,
          feelingColorHex: entry.feelingColorHex,
          drinks: entry.drinks,
          stepCount: entry.stepCount ?? null,
          walkingDistanceMeters: entry.walkingDistanceMeters ?? null,
          sleepHours: entry.sleepHours ?? null,
          screenTimeSeconds: entry.screenTimeSeconds ?? null,
          pickups: entry.pickups ?? null,
          updatedAt: new Date(entry.updatedAt),
        },
      });

    upsertedCount++;
  }

  // Log sync
  await db.insert(syncLog).values({
    userId,
    entriesPushed: upsertedCount,
  });

  return c.json({ syncedAt, count: upsertedCount });
});

// GET /entries — Fetch entries (optionally since timestamp)
app.get("/", async (c) => {
  const userId = c.get("userId");
  const since = c.req.query("since");
  const limit = Math.min(parseInt(c.req.query("limit") ?? "200"), 200);

  const db = createDb(c.env.DATABASE_URL);

  const cursor = c.req.query("cursor");

  const conditions = [eq(entries.userId, userId)];
  if (cursor) {
    conditions.push(gt(entries.updatedAt, new Date(cursor)));
  } else if (since) {
    conditions.push(gt(entries.updatedAt, new Date(since)));
  }

  const results = await db
    .select()
    .from(entries)
    .where(and(...conditions))
    .limit(limit)
    .orderBy(entries.updatedAt);

  const mappedEntries = results.map((row) => ({
    entryDate: row.entryDate,
    journalEntry: row.journalEntry,
    gratitude: row.gratitude,
    win: row.win,
    tension: row.tension,
    singleWordFeeling: row.singleWordFeeling,
    latitude: row.latitude,
    longitude: row.longitude,
    city: row.city,
    state: row.state,
    country: row.country,
    feeling: row.feeling,
    sleepQuality: row.sleepQuality,
    feelingColorHex: row.feelingColorHex,
    drinks: row.drinks,
    stepCount: row.stepCount,
    walkingDistanceMeters: row.walkingDistanceMeters,
    sleepHours: row.sleepHours,
    screenTimeSeconds: row.screenTimeSeconds,
    pickups: row.pickups,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  }));

  const nextCursor =
    results.length === limit
      ? results[results.length - 1].updatedAt.toISOString()
      : null;

  return c.json({ entries: mappedEntries, cursor: nextCursor });
});

// DELETE /entries/:date — Delete a single entry
app.delete("/:date", async (c) => {
  const userId = c.get("userId");
  const entryDate = c.req.param("date");

  const db = createDb(c.env.DATABASE_URL);

  await db
    .delete(entries)
    .where(and(eq(entries.userId, userId), eq(entries.entryDate, entryDate)));

  return c.json({ deleted: true });
});

export default app;
