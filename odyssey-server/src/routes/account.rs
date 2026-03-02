use axum::extract::State;
use axum::routing::delete;
use axum::{Json, Router};
use serde::Serialize;

use crate::AppState;
use crate::UserScope;
use crate::auth::AuthUser;
use crate::error::AppError;

pub fn router() -> Router<AppState> {
    Router::new().route("/account", delete(delete_account))
}

#[derive(Debug, Serialize)]
pub struct DeleteResponse {
    pub deleted: bool,
}

async fn delete_account(
    State(state): State<AppState>,
    user: AuthUser,
) -> Result<Json<DeleteResponse>, AppError> {
    let scope = UserScope::new(&user, &state);
    // ON DELETE CASCADE handles entries, encrypted_key_backups, sync_log
    sqlx::query("DELETE FROM users WHERE clerk_user_id = $1")
        .bind(&scope.user_id)
        .execute(&scope.pool)
        .await?;

    Ok(Json(DeleteResponse { deleted: true }))
}
