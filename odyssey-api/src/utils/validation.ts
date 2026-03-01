import { z } from "zod";

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
