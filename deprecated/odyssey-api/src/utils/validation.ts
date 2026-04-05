import { z } from "zod";
import { AppError } from "../middleware/error-handler";

export const syncEntrySchema = z.object({
  entryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),

  // Encrypted fields (base64 ciphertext, optional)
  journalEntry: z.string().nullable().optional(),
  gratitude: z.string().nullable().optional(),
  win: z.string().nullable().optional(),
  tension: z.string().nullable().optional(),
  singleWordFeeling: z.string().nullable().optional(),
  latitude: z.string().nullable().optional(),
  longitude: z.string().nullable().optional(),
  city: z.string().nullable().optional(),
  state: z.string().nullable().optional(),
  country: z.string().nullable().optional(),

  // Plaintext fields
  feeling: z.number().int().min(1).max(10),
  sleepQuality: z.number().int().min(1).max(10),
  feelingColorHex: z.string(),
  drinks: z.number().int().min(0),
  stepCount: z.number().int().nullable().optional(),
  walkingDistanceMeters: z.number().nullable().optional(),
  sleepHours: z.number().nullable().optional(),
  screenTimeSeconds: z.number().nullable().optional(),
  pickups: z.number().int().nullable().optional(),

  createdAt: z.string(),
  updatedAt: z.string(),
});

export const syncUploadSchema = z.object({
  entries: z.array(syncEntrySchema).min(1).max(100),
});

export const keyBackupSchema = z.object({
  encryptedKeyData: z.string().min(1),
  keyDerivationSalt: z.string().nullable().optional(),
});

export type SyncEntry = z.infer<typeof syncEntrySchema>;
export type SyncUploadPayload = z.infer<typeof syncUploadSchema>;
export type KeyBackupPayload = z.infer<typeof keyBackupSchema>;

// --- Post-parse validators ---

const encoder = new TextEncoder();
const HEX_COLOR_RE = /^#[0-9A-Fa-f]{6}$/;
const MAX_ENCRYPTED_FIELD_BYTES = 50_000;
const MAX_ENCRYPTED_KEY_DATA_BYTES = 10_240;
const MAX_KEY_DERIVATION_SALT_BYTES = 500;
const TIMESTAMP_DRIFT_MS = 48 * 60 * 60 * 1000; // 48 hours

export function validateByteLength(
  value: string | null | undefined,
  name: string,
  maxBytes: number
): void {
  if (value == null) return;
  const len = encoder.encode(value).byteLength;
  if (len > maxBytes) {
    throw AppError.validation(
      `${name} exceeds maximum length of ${maxBytes} bytes (got ${len})`
    );
  }
}

export function validateTimestamp(ts: string, fieldName: string): void {
  const parsed = Date.parse(ts);
  if (isNaN(parsed)) {
    throw AppError.validation(`Invalid ${fieldName} timestamp: ${ts}`);
  }
  const diff = Math.abs(Date.now() - parsed);
  if (diff > TIMESTAMP_DRIFT_MS) {
    throw AppError.validation(
      `${fieldName} is more than 48 hours from server time`
    );
  }
}

export function validateEntryDateRange(date: string): void {
  const parsed = new Date(date + "T00:00:00Z");
  if (isNaN(parsed.getTime())) {
    throw AppError.validation(`Invalid entry_date: ${date}`);
  }

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const oneDayFuture = new Date(today);
  oneDayFuture.setUTCDate(oneDayFuture.getUTCDate() + 1);

  const twoYearsPast = new Date(today);
  twoYearsPast.setUTCDate(twoYearsPast.getUTCDate() - 365 * 2);

  if (parsed > oneDayFuture) {
    throw AppError.validation(
      `entry_date ${date} is more than 1 day in the future`
    );
  }
  if (parsed < twoYearsPast) {
    throw AppError.validation(
      `entry_date ${date} is more than 2 years in the past`
    );
  }
}

export function validateHexColor(color: string): void {
  if (!HEX_COLOR_RE.test(color)) {
    throw AppError.validation(
      `Invalid hex color format: ${color}. Expected #RRGGBB`
    );
  }
}

export function validateSyncEntry(entry: SyncEntry): void {
  validateTimestamp(entry.createdAt, "createdAt");
  validateTimestamp(entry.updatedAt, "updatedAt");
  validateEntryDateRange(entry.entryDate);
  validateHexColor(entry.feelingColorHex);

  // Validate encrypted field byte lengths
  const encryptedFields: [string | null | undefined, string][] = [
    [entry.journalEntry, "journalEntry"],
    [entry.gratitude, "gratitude"],
    [entry.win, "win"],
    [entry.tension, "tension"],
    [entry.singleWordFeeling, "singleWordFeeling"],
    [entry.latitude, "latitude"],
    [entry.longitude, "longitude"],
    [entry.city, "city"],
    [entry.state, "state"],
    [entry.country, "country"],
  ];
  for (const [value, name] of encryptedFields) {
    validateByteLength(value, name, MAX_ENCRYPTED_FIELD_BYTES);
  }
}

export function validateKeyBackup(data: KeyBackupPayload): void {
  validateByteLength(
    data.encryptedKeyData,
    "encryptedKeyData",
    MAX_ENCRYPTED_KEY_DATA_BYTES
  );
  validateByteLength(
    data.keyDerivationSalt,
    "keyDerivationSalt",
    MAX_KEY_DERIVATION_SALT_BYTES
  );
}
