# Odyssey Load Tests

Locust-based load testing harness for the Odyssey Rust/Axum backend. Uses RSA keypair-based auth bypass to simulate authenticated users without requiring Clerk.

## Setup

```bash
# Install Python dependencies
pip install -r requirements.txt

# Generate RSA keypair (one-time)
make loadtest-keys
```

## Running

```bash
# Web UI mode — auto-starts backend if needed, opens Locust at :8089
make loadtest

# Headless mode — 100 users, 10/s spawn rate, 60s duration
make loadtest-headless
```

Both targets automatically start the Rust backend in load test mode if it's not already running.

### Manual server start

```bash
cd odyssey-server
ODYSSEY_LOADTEST_PUBLIC_KEY_PATH=loadtests/keys/test_public.pem \
ODYSSEY_LOADTEST_DISABLE_RATELIMIT=1 \
DATABASE_URL=<your_db_url> \
CLERK_JWKS_URL=https://example.com/.well-known/jwks.json \
cargo run
```

## User Classes

| Class | Weight | Behavior |
|-------|--------|----------|
| **CasualUser** | 5 | Daily journaling — syncs 1-2 entries, reads recent, occasional deletes |
| **HeavySyncer** | 3 | Bulk operations — batch uploads (10-50 entries), full reads, date-range queries |
| **KeyBackupUser** | 2 | Key management — stores and retrieves encrypted key backups |

## Environment Variables

### Rust Backend

| Variable | Description |
|----------|-------------|
| `ODYSSEY_LOADTEST_PUBLIC_KEY_PATH` | Path to RSA public key PEM for token validation |
| `ODYSSEY_LOADTEST_DISABLE_RATELIMIT` | Set to `1` or `true` to disable rate limiting |

### Python Load Tests

| Variable | Default | Description |
|----------|---------|-------------|
| `ODYSSEY_LOADTEST_HOST` | `http://localhost:8080` | Target server URL |
| `ODYSSEY_LOADTEST_PRIVATE_KEY_PATH` | `keys/test_private.pem` | Path to RSA private key for signing JWTs |
| `ODYSSEY_LOADTEST_WAIT_MIN` | `1` | Minimum wait between tasks (seconds) |
| `ODYSSEY_LOADTEST_WAIT_MAX` | `5` | Maximum wait between tasks (seconds) |

## How It Works

1. `make loadtest-keys` generates an RSA keypair in `keys/`
2. The Rust backend is started with the public key path, enabling load test auth bypass
3. Locust users sign JWTs with the private key — the backend validates them directly without JWKS
4. Rate limiting is disabled so load test traffic isn't throttled
