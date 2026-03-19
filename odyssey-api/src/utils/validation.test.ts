import { describe, it, expect } from "vitest";
import {
  validateTimestamp,
  validateEntryDateRange,
  validateByteLength,
  validateHexColor,
  validateSyncEntry,
  validateKeyBackup,
  type SyncEntry,
  type KeyBackupPayload,
} from "./validation";

describe("validateTimestamp", () => {
  it("accepts a timestamp within ±48h", () => {
    const now = new Date().toISOString();
    expect(() => validateTimestamp(now, "createdAt")).not.toThrow();
  });

  it("accepts a timestamp 47h in the past", () => {
    const ts = new Date(Date.now() - 47 * 60 * 60 * 1000).toISOString();
    expect(() => validateTimestamp(ts, "createdAt")).not.toThrow();
  });

  it("rejects a timestamp >48h in the past", () => {
    const ts = new Date(Date.now() - 49 * 60 * 60 * 1000).toISOString();
    expect(() => validateTimestamp(ts, "createdAt")).toThrow(
      "more than 48 hours from server time"
    );
  });

  it("rejects a timestamp >48h in the future", () => {
    const ts = new Date(Date.now() + 49 * 60 * 60 * 1000).toISOString();
    expect(() => validateTimestamp(ts, "updatedAt")).toThrow(
      "more than 48 hours from server time"
    );
  });

  it("rejects an invalid timestamp string", () => {
    expect(() => validateTimestamp("not-a-date", "createdAt")).toThrow(
      "Invalid createdAt timestamp"
    );
  });
});

describe("validateEntryDateRange", () => {
  function dateString(offsetDays: number): string {
    const d = new Date();
    d.setUTCHours(0, 0, 0, 0);
    d.setUTCDate(d.getUTCDate() + offsetDays);
    return d.toISOString().slice(0, 10);
  }

  it("accepts today", () => {
    expect(() => validateEntryDateRange(dateString(0))).not.toThrow();
  });

  it("accepts 1 day in the future", () => {
    expect(() => validateEntryDateRange(dateString(1))).not.toThrow();
  });

  it("rejects 2 days in the future", () => {
    expect(() => validateEntryDateRange(dateString(2))).toThrow(
      "more than 1 day in the future"
    );
  });

  it("accepts ~2 years in the past", () => {
    expect(() => validateEntryDateRange(dateString(-729))).not.toThrow();
  });

  it("rejects >2 years in the past", () => {
    expect(() => validateEntryDateRange(dateString(-731))).toThrow(
      "more than 2 years in the past"
    );
  });
});

describe("validateByteLength", () => {
  it("accepts null/undefined", () => {
    expect(() => validateByteLength(null, "field", 10)).not.toThrow();
    expect(() => validateByteLength(undefined, "field", 10)).not.toThrow();
  });

  it("accepts a string within the limit", () => {
    expect(() => validateByteLength("hello", "field", 10)).not.toThrow();
  });

  it("rejects a string exceeding byte limit", () => {
    expect(() => validateByteLength("hello world", "field", 5)).toThrow(
      "exceeds maximum length of 5 bytes"
    );
  });

  it("counts bytes not chars for multi-byte characters", () => {
    // Emoji: 🎉 is 4 bytes in UTF-8
    expect(() => validateByteLength("🎉", "field", 3)).toThrow(
      "exceeds maximum length of 3 bytes"
    );
    expect(() => validateByteLength("🎉", "field", 4)).not.toThrow();
  });

  it("counts bytes for CJK characters", () => {
    // CJK character: 日 is 3 bytes in UTF-8
    expect(() => validateByteLength("日", "field", 2)).toThrow(
      "exceeds maximum length of 2 bytes"
    );
    expect(() => validateByteLength("日", "field", 3)).not.toThrow();
  });
});

describe("validateHexColor", () => {
  it("accepts valid hex colors", () => {
    expect(() => validateHexColor("#FF0000")).not.toThrow();
    expect(() => validateHexColor("#00ff00")).not.toThrow();
    expect(() => validateHexColor("#aaBBcc")).not.toThrow();
  });

  it("rejects invalid hex colors", () => {
    expect(() => validateHexColor("FF0000")).toThrow("Invalid hex color");
    expect(() => validateHexColor("#FFF")).toThrow("Invalid hex color");
    expect(() => validateHexColor("#GGGGGG")).toThrow("Invalid hex color");
    expect(() => validateHexColor("#FF00001")).toThrow("Invalid hex color");
    expect(() => validateHexColor("")).toThrow("Invalid hex color");
  });
});

describe("validateSyncEntry", () => {
  function makeEntry(overrides: Partial<SyncEntry> = {}): SyncEntry {
    return {
      entryDate: new Date().toISOString().slice(0, 10),
      feeling: 5,
      sleepQuality: 7,
      feelingColorHex: "#FF5733",
      drinks: 2,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      ...overrides,
    };
  }

  it("accepts a valid entry", () => {
    expect(() => validateSyncEntry(makeEntry())).not.toThrow();
  });

  it("rejects invalid hex color", () => {
    expect(() =>
      validateSyncEntry(makeEntry({ feelingColorHex: "red" }))
    ).toThrow("Invalid hex color");
  });

  it("rejects stale timestamps", () => {
    const old = new Date(Date.now() - 50 * 60 * 60 * 1000).toISOString();
    expect(() => validateSyncEntry(makeEntry({ createdAt: old }))).toThrow(
      "more than 48 hours"
    );
  });
});

describe("validateKeyBackup", () => {
  it("accepts valid key backup", () => {
    const data: KeyBackupPayload = {
      encryptedKeyData: "abc123",
      keyDerivationSalt: "salt",
    };
    expect(() => validateKeyBackup(data)).not.toThrow();
  });

  it("rejects oversized encryptedKeyData", () => {
    const data: KeyBackupPayload = {
      encryptedKeyData: "x".repeat(10_241),
    };
    expect(() => validateKeyBackup(data)).toThrow(
      "encryptedKeyData exceeds maximum length of 10240 bytes"
    );
  });

  it("rejects oversized keyDerivationSalt", () => {
    const data: KeyBackupPayload = {
      encryptedKeyData: "ok",
      keyDerivationSalt: "x".repeat(501),
    };
    expect(() => validateKeyBackup(data)).toThrow(
      "keyDerivationSalt exceeds maximum length of 500 bytes"
    );
  });

  it("accepts encryptedKeyData at exact limit", () => {
    const data: KeyBackupPayload = {
      encryptedKeyData: "x".repeat(10_240),
    };
    expect(() => validateKeyBackup(data)).not.toThrow();
  });
});
