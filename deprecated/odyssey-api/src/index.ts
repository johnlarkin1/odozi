import { Hono } from "hono";
import { cors } from "hono/cors";
import { bodyLimit } from "hono/body-limit";
import { securityHeaders } from "./middleware/security-headers";
import { authMiddleware } from "./auth/middleware";
import { rateLimitMiddleware } from "./middleware/rate-limit";
import { errorHandler } from "./middleware/error-handler";
import entriesRoutes from "./routes/entries";
import accountRoutes from "./routes/account";
import keyBackupRoutes from "./routes/key-backup";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env; Variables: { userId: string } }>();

// Global middleware
app.use("*", securityHeaders);
app.use("*", cors());
app.use("*", bodyLimit({ maxSize: 5 * 1024 * 1024 }));
app.onError(errorHandler);

// Health check (no auth)
app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.get("/healthz", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Rate limit before auth (IP-based, catches unauthenticated abuse)
app.use("*", rateLimitMiddleware);

// All other routes require auth
app.use("*", authMiddleware);

// Routes
app.route("/entries", entriesRoutes);
app.route("/account", accountRoutes);
app.route("/key-backup", keyBackupRoutes);

export default app;
