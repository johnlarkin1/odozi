-- Initial migration: Create tables for Odyssey cloud backup

CREATE TABLE IF NOT EXISTS users (
  clerk_user_id TEXT PRIMARY KEY,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_sync_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS entries (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(clerk_user_id) ON DELETE CASCADE,
  entry_date DATE NOT NULL,

  -- Encrypted fields (client-side E2E encrypted ciphertext)
  journal_entry TEXT,
  gratitude TEXT,
  win TEXT,
  tension TEXT,
  single_word_feeling TEXT,
  latitude TEXT,
  longitude TEXT,
  city TEXT,
  state TEXT,
  country TEXT,

  -- Plaintext fields (non-identifying numeric metrics)
  feeling INTEGER NOT NULL,
  sleep_quality INTEGER NOT NULL,
  feeling_color_hex TEXT NOT NULL,
  drinks INTEGER NOT NULL,
  step_count INTEGER,
  walking_distance_meters DOUBLE PRECISION,
  sleep_hours DOUBLE PRECISION,
  screen_time_seconds DOUBLE PRECISION,
  pickups INTEGER,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX entries_user_date_idx ON entries(user_id, entry_date);

CREATE TABLE IF NOT EXISTS encrypted_key_backups (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE REFERENCES users(clerk_user_id) ON DELETE CASCADE,
  encrypted_key_data TEXT NOT NULL,
  key_derivation_salt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sync_log (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(clerk_user_id) ON DELETE CASCADE,
  device_id TEXT,
  entries_pushed INTEGER DEFAULT 0,
  entries_pulled INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Data isolation is enforced at the application layer (userId from
-- verified Clerk JWT in every query). Session-based RLS is incompatible
-- with the Neon HTTP driver which runs each query in its own transaction.
