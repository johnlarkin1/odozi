mod auth;
mod config;
mod db;
mod error;
mod models;
mod rate_limit;
mod routes;
mod validation;

use std::sync::Arc;

use axum::middleware;
use axum::{Json, Router, routing::get};
use serde_json::json;
use sqlx::PgPool;
use tokio::net::TcpListener;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::auth::JwksCache;
use crate::config::Config;
use crate::rate_limit::RateLimiter;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwks: Arc<JwksCache>,
    pub config: Config,
}

async fn health() -> Json<serde_json::Value> {
    Json(json!({
        "status": "ok",
        "timestamp": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
    }))
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "odyssey_server=info,tower_http=info".into()),
        )
        .init();

    dotenvy::dotenv().ok();
    let config = Config::from_env();
    let port = config.port;

    let pool = db::create_pool(&config)
        .await
        .expect("Failed to connect to database");

    let jwks = Arc::new(JwksCache::new(&config.clerk_jwks_url));

    let state = AppState {
        db: pool,
        jwks,
        config,
    };

    let limiter = RateLimiter::new();

    let app = Router::new()
        .route("/healthz", get(health))
        .merge(routes::router())
        .with_state(state)
        .layer(middleware::from_fn(rate_limit::rate_limit_middleware))
        .layer(axum::Extension(limiter))
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::very_permissive());

    let addr = format!("0.0.0.0:{port}");
    tracing::info!("Listening on {addr}");
    let listener = TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
