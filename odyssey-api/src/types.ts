export interface Env {
  DATABASE_URL: string;
  CLERK_JWKS_URL: string;
  CLERK_PUBLISHABLE_KEY: string;
}

export interface AuthContext {
  userId: string;
}
