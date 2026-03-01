import { Hono } from "hono";
import { cors } from "hono/cors";
import { authMiddleware } from "./auth/middleware";
import { rateLimitMiddleware } from "./middleware/rate-limit";
import { errorHandler } from "./middleware/error-handler";
import entriesRoutes from "./routes/entries";
import accountRoutes from "./routes/account";
import keyBackupRoutes from "./routes/key-backup";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env; Variables: { userId: string } }>();

// Global middleware
app.use("*", cors());
app.onError(errorHandler);

// Health check (no auth)
app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

// All other routes require auth
app.use("*", authMiddleware);
app.use("*", rateLimitMiddleware);

// Routes
app.route("/entries", entriesRoutes);
app.route("/account", accountRoutes);
app.route("/key-backup", keyBackupRoutes);

export default app;
