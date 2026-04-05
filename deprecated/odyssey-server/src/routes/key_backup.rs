use axum::extract::State;
use axum::routing::{get, put};
use axum::{Json, Router};
use serde::{Deserialize, Serialize};

use crate::AppState;
use crate::UserScope;
use crate::auth::AuthUser;
use crate::error::AppError;
use crate::validation;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/key-backup", put(store_key_backup))
        .route("/key-backup", get(get_key_backup))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyBackupInput {
    pub encrypted_key_data: String,
    pub key_derivation_salt: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyBackupResponse {
    pub encrypted_key_data: String,
    pub key_derivation_salt: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct StoredResponse {
    pub stored: bool,
}

async fn store_key_backup(
    State(state): State<AppState>,
    user: AuthUser,
    Json(body): Json<KeyBackupInput>,
) -> Result<Json<StoredResponse>, AppError> {
    let scope = UserScope::new(&user, &state);

    if body.encrypted_key_data.is_empty() {
        return Err(AppError::Validation(
            "encryptedKeyData must not be empty".to_string(),
        ));
    }

    // Length constraints
    validation::validate_required_field_length(
        &body.encrypted_key_data,
        "encryptedKeyData",
        10 * 1024, // 10 KB
    )?;
    validation::validate_encrypted_field_length(
        &body.key_derivation_salt,
        "keyDerivationSalt",
        500,
    )?;

    // Upsert user (ON CONFLICT DO NOTHING — don't update last_sync_at)
    sqlx::query(
        "INSERT INTO users (clerk_user_id) VALUES ($1)
         ON CONFLICT (clerk_user_id) DO NOTHING",
    )
    .bind(&scope.user_id)
    .execute(&scope.pool)
    .await?;

    // Upsert key backup
    sqlx::query(
        "INSERT INTO encrypted_key_backups (user_id, encrypted_key_data, key_derivation_salt)
         VALUES ($1, $2, $3)
         ON CONFLICT (user_id) DO UPDATE SET
            encrypted_key_data = EXCLUDED.encrypted_key_data,
            key_derivation_salt = EXCLUDED.key_derivation_salt,
            updated_at = NOW()",
    )
    .bind(&scope.user_id)
    .bind(&body.encrypted_key_data)
    .bind(&body.key_derivation_salt)
    .execute(&scope.pool)
    .await?;

    Ok(Json(StoredResponse { stored: true }))
}

async fn get_key_backup(
    State(state): State<AppState>,
    user: AuthUser,
) -> Result<Json<KeyBackupResponse>, AppError> {
    let scope = UserScope::new(&user, &state);
    let row = sqlx::query_as::<_, (String, Option<String>)>(
        "SELECT encrypted_key_data, key_derivation_salt
         FROM encrypted_key_backups WHERE user_id = $1 LIMIT 1",
    )
    .bind(&scope.user_id)
    .fetch_optional(&scope.pool)
    .await?;

    match row {
        Some((encrypted_key_data, key_derivation_salt)) => Ok(Json(KeyBackupResponse {
            encrypted_key_data,
            key_derivation_salt,
        })),
        None => Err(AppError::NotFound("No key backup found".to_string())),
    }
}
