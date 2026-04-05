use chrono::{DateTime, NaiveDate, Utc};

use crate::error::AppError;

/// Validate entry_date matches YYYY-MM-DD format.
pub fn validate_entry_date(date: &str) -> Result<(), AppError> {
    let re = regex_lite::Regex::new(r"^\d{4}-\d{2}-\d{2}$").unwrap();
    if !re.is_match(date) {
        return Err(AppError::Validation(format!(
            "Invalid entry_date format: {date}. Expected YYYY-MM-DD"
        )));
    }
    Ok(())
}

/// Parse and validate an ISO 8601 timestamp, rejecting values >48h from server time.
pub fn validate_timestamp(ts: &str, field_name: &str) -> Result<DateTime<Utc>, AppError> {
    let parsed: DateTime<Utc> = ts.parse().map_err(|e| {
        AppError::Validation(format!("Invalid {field_name} timestamp: {e}"))
    })?;

    let now = Utc::now();
    let diff = (now - parsed).abs();
    let max_drift = chrono::Duration::hours(48);

    if diff > max_drift {
        return Err(AppError::Validation(format!(
            "{field_name} is more than 48 hours from server time"
        )));
    }

    Ok(parsed)
}

/// Parse and validate an entry date string, rejecting dates >1 day in the future
/// or >2 years in the past.
pub fn validate_entry_date_range(date: &str) -> Result<NaiveDate, AppError> {
    let parsed = date.parse::<NaiveDate>().map_err(|e| {
        AppError::Validation(format!("Invalid entry_date: {e}"))
    })?;

    let today = Utc::now().date_naive();
    let one_day_future = today + chrono::Duration::days(1);
    let two_years_past = today - chrono::Duration::days(365 * 2);

    if parsed > one_day_future {
        return Err(AppError::Validation(format!(
            "entry_date {date} is more than 1 day in the future"
        )));
    }

    if parsed < two_years_past {
        return Err(AppError::Validation(format!(
            "entry_date {date} is more than 2 years in the past"
        )));
    }

    Ok(parsed)
}

/// Validate feeling is 1-10.
pub fn validate_feeling(val: i32) -> Result<(), AppError> {
    if !(1..=10).contains(&val) {
        return Err(AppError::Validation(format!(
            "feeling must be between 1 and 10, got {val}"
        )));
    }
    Ok(())
}

/// Validate sleep_quality is 1-10.
pub fn validate_sleep_quality(val: i32) -> Result<(), AppError> {
    if !(1..=10).contains(&val) {
        return Err(AppError::Validation(format!(
            "sleepQuality must be between 1 and 10, got {val}"
        )));
    }
    Ok(())
}

/// Validate drinks >= 0.
pub fn validate_drinks(val: i32) -> Result<(), AppError> {
    if val < 0 {
        return Err(AppError::Validation(format!(
            "drinks must be >= 0, got {val}"
        )));
    }
    Ok(())
}

/// Validate that an optional encrypted string field does not exceed `max_len` bytes.
pub fn validate_encrypted_field_length(
    value: &Option<String>,
    name: &str,
    max_len: usize,
) -> Result<(), AppError> {
    if let Some(v) = value {
        if v.len() > max_len {
            return Err(AppError::Validation(format!(
                "{name} exceeds maximum length of {max_len} bytes (got {})",
                v.len()
            )));
        }
    }
    Ok(())
}

/// Validate that a required string field does not exceed `max_len` bytes.
pub fn validate_required_field_length(
    value: &str,
    name: &str,
    max_len: usize,
) -> Result<(), AppError> {
    if value.len() > max_len {
        return Err(AppError::Validation(format!(
            "{name} exceeds maximum length of {max_len} bytes (got {})",
            value.len()
        )));
    }
    Ok(())
}

/// Validate a hex color string matches `#RRGGBB` format.
pub fn validate_hex_color(color: &str) -> Result<(), AppError> {
    let re = regex_lite::Regex::new(r"^#[0-9A-Fa-f]{6}$").unwrap();
    if !re.is_match(color) {
        return Err(AppError::Validation(format!(
            "Invalid hex color format: {color}. Expected #RRGGBB"
        )));
    }
    Ok(())
}
