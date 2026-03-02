use std::env;

#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub clerk_jwks_url: String,
    pub clerk_expected_audience: Option<String>,
    pub port: u16,
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
        }
    }
}
