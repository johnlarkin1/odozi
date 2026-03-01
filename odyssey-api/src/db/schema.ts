import {
  pgTable,
  text,
  timestamp,
  date,
  integer,
  doublePrecision,
  uniqueIndex,
  pgPolicy,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const users = pgTable("users", {
  clerkUserId: text("clerk_user_id").primaryKey(),
  email: text("email"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
  lastSyncAt: timestamp("last_sync_at", { withTimezone: true }),
});

export const entries = pgTable(
  "entries",
  {
    id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
    userId: text("user_id")
      .references(() => users.clerkUserId, { onDelete: "cascade" })
      .notNull(),
    entryDate: date("entry_date").notNull(),

    // Encrypted fields (ciphertext)
    journalEntry: text("journal_entry"),
    gratitude: text("gratitude"),
    win: text("win"),
    tension: text("tension"),
    singleWordFeeling: text("single_word_feeling"),
    latitude: text("latitude"),
    longitude: text("longitude"),
    city: text("city"),
    state: text("state"),
    country: text("country"),

    // Plaintext fields (non-identifying metrics)
    feeling: integer("feeling").notNull(),
    sleepQuality: integer("sleep_quality").notNull(),
    feelingColorHex: text("feeling_color_hex").notNull(),
    drinks: integer("drinks").notNull(),
    stepCount: integer("step_count"),
    walkingDistanceMeters: doublePrecision("walking_distance_meters"),
    sleepHours: doublePrecision("sleep_hours"),
    screenTimeSeconds: doublePrecision("screen_time_seconds"),
    pickups: integer("pickups"),

    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [uniqueIndex("entries_user_date_idx").on(table.userId, table.entryDate)]
);

export const encryptedKeyBackups = pgTable(
  "encrypted_key_backups",
  {
    id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
    userId: text("user_id")
      .references(() => users.clerkUserId, { onDelete: "cascade" })
      .notNull()
      .unique(),
    encryptedKeyData: text("encrypted_key_data").notNull(),
    keyDerivationSalt: text("key_derivation_salt"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  }
);

export const syncLog = pgTable("sync_log", {
  id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
  userId: text("user_id")
    .references(() => users.clerkUserId, { onDelete: "cascade" })
    .notNull(),
  deviceId: text("device_id"),
  entriesPushed: integer("entries_pushed").default(0),
  entriesPulled: integer("entries_pulled").default(0),
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
});
