use sqlx::PgPool;

use crate::AppState;
use crate::auth::AuthUser;

/// Bundles the authenticated user ID and database pool together, ensuring
/// every query is scoped to the correct user. Constructed at the top of
/// each route handler to replace ad-hoc `user.user_id` / `state.db` access.
pub struct UserScope {
    pub user_id: String,
    pub pool: PgPool,
}

impl UserScope {
    pub fn new(user: &AuthUser, state: &AppState) -> Self {
        Self {
            user_id: user.user_id.clone(),
            pool: state.db.clone(),
        }
    }
}
