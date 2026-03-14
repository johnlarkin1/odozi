use std::env;

#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub clerk_jwks_url: String,
    pub clerk_expected_audience: Option<String>,
    pub port: u16,
    pub loadtest_public_key_path: Option<String>,
    pub loadtest_disable_ratelimit: bool,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            clerk_jwks_url: env::var("CLERK_JWKS_URL").expect("CLERK_JWKS_URL must be set"),
            clerk_expected_audience: env::var("CLERK_EXPECTED_AUDIENCE").ok(),
            port: env::var("PORT")
                .ok()
                .and_then(|p| p.parse().ok())
                .unwrap_or(8080),
            loadtest_public_key_path: env::var("ODYSSEY_LOADTEST_PUBLIC_KEY_PATH").ok(),
            loadtest_disable_ratelimit: env::var("ODYSSEY_LOADTEST_DISABLE_RATELIMIT")
                .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                .unwrap_or(false),
        }
    }
}
