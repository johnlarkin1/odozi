pub mod account;
pub mod entries;
pub mod key_backup;

use axum::Router;

use crate::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .merge(entries::router())
        .merge(account::router())
        .merge(key_backup::router())
}
