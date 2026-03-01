import type { Database } from "./client";

/**
 * Data isolation wrapper.
 *
 * Data isolation is enforced at the application layer: every query in
 * entries.ts, key-backup.ts, and account.ts filters by
 * `eq(entries.userId, userId)` where userId comes from the verified
 * Clerk JWT.
 *
 * Session-based RLS (`SET LOCAL app.current_user_id`) is incompatible
 * with the Neon HTTP driver, which runs each query in its own implicit
 * transaction. The SET LOCAL would be lost before the next query
 * executes, making the RLS policies evaluate against an empty string
 * and silently returning zero rows.
 *
 * If you migrate to the Neon WebSocket driver (with explicit
 * transactions), you can re-enable RLS at the database level as an
 * additional safety layer.
 */
export async function withRLS<T>(
  db: Database,
  userId: string,
  fn: (db: Database) => Promise<T>
): Promise<T> {
  return fn(db);
}
