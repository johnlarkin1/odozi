use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;

use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use serde_json::json;
use tokio::sync::Mutex;

const MAX_REQUESTS: u32 = 60;
const WINDOW_SECS: u64 = 60;

struct RateLimitEntry {
    count: u32,
    reset_at: Instant,
}

#[derive(Clone)]
pub struct RateLimiter {
    state: Arc<Mutex<HashMap<String, RateLimitEntry>>>,
    enabled: bool,
}

impl RateLimiter {
    pub fn new(enabled: bool) -> Self {
        Self {
            state: Arc::new(Mutex::new(HashMap::new())),
            enabled,
        }
    }
}

fn extract_client_ip(req: &axum::extract::Request) -> String {
    // Try X-Forwarded-For first (Render/proxy), then X-Real-IP, then fallback
    req.headers()
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.split(',').next().unwrap_or("unknown").trim().to_string())
        .or_else(|| {
            req.headers()
                .get("x-real-ip")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string())
        })
        .unwrap_or_else(|| "unknown".to_string())
}

pub async fn rate_limit_middleware(
    axum::Extension(limiter): axum::Extension<RateLimiter>,
    request: axum::extract::Request,
    next: Next,
) -> Response {
    if !limiter.enabled {
        return next.run(request).await;
    }

    let key = extract_client_ip(&request);
    let now = Instant::now();
    let window = std::time::Duration::from_secs(WINDOW_SECS);

    {
        let mut state = limiter.state.lock().await;
        let entry = state.entry(key).or_insert_with(|| RateLimitEntry {
            count: 0,
            reset_at: now + window,
        });

        if now >= entry.reset_at {
            entry.count = 1;
            entry.reset_at = now + window;
        } else {
            entry.count += 1;
            if entry.count > MAX_REQUESTS {
                let body = json!({ "error": "Rate limit exceeded" });
                return (StatusCode::TOO_MANY_REQUESTS, axum::Json(body)).into_response();
            }
        }
    }

    next.run(request).await
}
