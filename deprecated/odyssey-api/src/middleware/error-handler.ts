import { Context } from "hono";

export class AppError extends Error {
  readonly statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }

  static validation(msg: string): AppError {
    return new AppError(msg, 400);
  }

  static unauthorized(msg: string): AppError {
    return new AppError(msg, 401);
  }

  static notFound(msg: string): AppError {
    return new AppError(msg, 404);
  }

  static rateLimited(): AppError {
    return new AppError("Rate limit exceeded", 429);
  }

  static internal(msg: string): AppError {
    return new AppError(msg, 500);
  }
}

export function errorHandler(err: Error, c: Context) {
  if (err instanceof AppError) {
    if (err.statusCode === 500) {
      console.error("Internal error:", err);
    }
    return c.json({ error: err.message }, err.statusCode as any);
  }

  console.error("Unhandled error:", err);
  return c.json({ error: "Internal server error" }, 500);
}
