import { Context, Next } from "hono";
import { verifyClerkJWT } from "./clerk";
import type { Env } from "../types";

export async function authMiddleware(c: Context<{ Bindings: Env }>, next: Next) {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Missing authorization header" }, 401);
  }

  const token = authHeader.slice(7);

  try {
    const userId = await verifyClerkJWT(token, c.env.CLERK_JWKS_URL);
    c.set("userId", userId);
    await next();
  } catch (error) {
    return c.json({ error: "Invalid or expired token" }, 401);
  }
}
