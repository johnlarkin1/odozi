mod auth;
mod config;
mod db;
mod error;
mod models;
mod rate_limit;
mod routes;
mod scoped_query;
mod validation;

pub use scoped_query::UserScope;

use std::sync::Arc;

use axum::extract::DefaultBodyLimit;
use axum::http::{HeaderValue, Method, header};
use axum::middleware;
use axum::{Json, Router, routing::get};
use jsonwebtoken::DecodingKey;
use serde_json::json;
use sqlx::PgPool;
use tokio::net::TcpListener;
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::set_header::SetResponseHeaderLayer;
use tower_http::trace::TraceLayer;

use crate::auth::JwksCache;
use crate::config::Config;
use crate::rate_limit::RateLimiter;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwks: Arc<JwksCache>,
    pub config: Config,
    pub loadtest_key: Option<DecodingKey>,
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

    let loadtest_key = if let Some(ref path) = config.loadtest_public_key_path {
        let pem = std::fs::read(path).expect("Failed to read loadtest public key PEM file");
        let key = DecodingKey::from_rsa_pem(&pem).expect("Invalid RSA PEM for loadtest key");
        tracing::warn!("LOAD TEST MODE ACTIVE — accepting tokens signed with {path}");
        Some(key)
    } else {
        None
    };

    if config.loadtest_disable_ratelimit {
        tracing::warn!("LOAD TEST MODE — rate limiting is DISABLED");
    }

    let limiter = RateLimiter::new(!config.loadtest_disable_ratelimit);

    let state = AppState {
        db: pool,
        jwks,
        config,
        loadtest_key,
    };

    let cors = CorsLayer::new()
        .allow_origin(AllowOrigin::predicate(|origin: &HeaderValue, _| {
            // Allow the iOS app (no Origin header) and localhost for dev
            origin.as_bytes().starts_with(b"http://localhost")
        }))
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE]);

    let app = Router::new()
        .route("/healthz", get(health))
        .merge(routes::router())
        .with_state(state)
        .layer(DefaultBodyLimit::max(5 * 1024 * 1024)) // 5 MB
        .layer(middleware::from_fn(rate_limit::rate_limit_middleware))
        .layer(axum::Extension(limiter))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("x-content-type-options"),
            HeaderValue::from_static("nosniff"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("x-frame-options"),
            HeaderValue::from_static("DENY"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::STRICT_TRANSPORT_SECURITY,
            HeaderValue::from_static("max-age=31536000; includeSubDomains"),
        ))
        .layer(TraceLayer::new_for_http())
        .layer(cors);

    let addr = format!("0.0.0.0:{port}");
    tracing::info!("Listening on {addr}");
    let listener = TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
