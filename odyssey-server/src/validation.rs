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
