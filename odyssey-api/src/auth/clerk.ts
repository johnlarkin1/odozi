import { createRemoteJWKSet, jwtVerify } from "jose";

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function getJWKS(jwksUrl: string) {
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(jwksUrl));
  }
  return jwks;
}

export async function verifyClerkJWT(
  token: string,
  jwksUrl: string
): Promise<string> {
  const keySet = getJWKS(jwksUrl);
  const { payload } = await jwtVerify(token, keySet);

  const userId = payload.sub;
  if (!userId) {
    throw new Error("JWT missing sub claim");
  }

  return userId;
}
