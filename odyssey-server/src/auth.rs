use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};
use serde::Deserialize;
use tokio::sync::RwLock;

use crate::AppState;
use crate::error::AppError;

#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: String,
}

#[derive(Debug, Deserialize)]
struct Claims {
    sub: Option<String>,
}

#[derive(Debug, Deserialize)]
struct JwksResponse {
    keys: Vec<JwkKey>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct JwkKey {
    pub kid: Option<String>,
    pub kty: String,
    pub n: String,
    pub e: String,
}

pub struct JwksCache {
    url: String,
    keys: RwLock<Vec<JwkKey>>,
}

impl JwksCache {
    pub fn new(url: &str) -> Self {
        Self {
            url: url.to_string(),
            keys: RwLock::new(Vec::new()),
        }
    }

    async fn fetch_keys(&self) -> Result<Vec<JwkKey>, AppError> {
        let resp: JwksResponse = reqwest::get(&self.url)
            .await
            .map_err(|e| AppError::Unauthorized(format!("Failed to fetch JWKS: {e}")))?
            .json()
            .await
            .map_err(|e| AppError::Unauthorized(format!("Failed to parse JWKS: {e}")))?;
        Ok(resp.keys)
    }

    pub async fn get_keys(&self) -> Result<Vec<JwkKey>, AppError> {
        {
            let cached = self.keys.read().await;
            if !cached.is_empty() {
                return Ok(cached.clone());
            }
        }

        let keys = self.fetch_keys().await?;
        {
            let mut cache = self.keys.write().await;
            *cache = keys.clone();
        }
        Ok(keys)
    }

    /// Force refresh of JWKS keys (used when kid doesn't match cached keys).
    pub async fn refresh_keys(&self) -> Result<Vec<JwkKey>, AppError> {
        let keys = self.fetch_keys().await?;
        let mut cache = self.keys.write().await;
        *cache = keys.clone();
        Ok(keys)
    }
}

fn find_key_by_kid<'a>(keys: &'a [JwkKey], kid: Option<&str>) -> Option<&'a JwkKey> {
    match kid {
        Some(kid) => keys.iter().find(|k| k.kid.as_deref() == Some(kid)),
        None => keys.first(),
    }
}

fn decode_token(key: &JwkKey, token: &str, expected_audience: Option<&str>) -> Result<Claims, AppError> {
    let decoding_key = DecodingKey::from_rsa_components(&key.n, &key.e)
        .map_err(|e| AppError::Unauthorized(format!("Invalid RSA key: {e}")))?;

    let mut validation = Validation::new(Algorithm::RS256);
    if let Some(aud) = expected_audience {
        validation.validate_aud = true;
        validation.set_audience(&[aud]);
    } else {
        validation.validate_aud = false;
    }

    let data = decode::<Claims>(token, &decoding_key, &validation)
        .map_err(|e| AppError::Unauthorized(format!("Invalid or expired token: {e}")))?;

    Ok(data.claims)
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::Unauthorized("Missing authorization header".to_string()))?;

        if !auth_header.starts_with("Bearer ") {
            return Err(AppError::Unauthorized(
                "Missing authorization header".to_string(),
            ));
        }

        let token = &auth_header[7..];

        // Extract kid from token header
        let header = jsonwebtoken::decode_header(token)
            .map_err(|e| AppError::Unauthorized(format!("Invalid token header: {e}")))?;

        let jwks = &state.jwks;
        let expected_aud = state.config.clerk_expected_audience.as_deref();

        // Try cached keys first
        let keys = jwks.get_keys().await?;
        let key = find_key_by_kid(&keys, header.kid.as_deref());

        let claims = match key {
            Some(k) => decode_token(k, token, expected_aud)?,
            None => {
                // Kid not found in cache — refresh and retry
                let refreshed = jwks.refresh_keys().await?;
                let k = find_key_by_kid(&refreshed, header.kid.as_deref()).ok_or_else(|| {
                    AppError::Unauthorized("No matching key found in JWKS".to_string())
                })?;
                decode_token(k, token, expected_aud)?
            }
        };

        let user_id = claims
            .sub
            .ok_or_else(|| AppError::Unauthorized("JWT missing sub claim".to_string()))?;

        Ok(AuthUser { user_id })
    }
}
