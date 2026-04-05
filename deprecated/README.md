# Deprecated

Backend implementations moved here from the repo root. Neither is deployed or used by the iOS app in production.

- **odyssey-server/** — Rust/Axum backend (Render). Dormant since March 2025, superseded by odyssey-api.
- **odyssey-api/** — TypeScript/Hono on Cloudflare Workers. Production-ready but never deployed. See proposal 005 for design context.

The iOS app operates local-first. The sync client (`APIClient.swift`, `ServerConfiguration.swift`) gracefully handles a missing backend by returning nil.
