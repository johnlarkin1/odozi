use axum::extract::{Path, Query, State};
use axum::routing::{delete, get, post};
use axum::{Json, Router};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::AppState;
use crate::UserScope;
use crate::auth::AuthUser;
use crate::error::AppError;
use crate::models::EntryResponse;
use crate::validation;

/// Pre-validated entry fields produced by the validation loop.
struct ValidatedEntry {
    entry_date: NaiveDate,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/entries", post(create_entries))
        .route("/entries", get(list_entries))
        .route("/entries/{date}", delete(delete_entry))
}

// --- POST /entries ---

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncUploadRequest {
    pub entries: Vec<EntryInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EntryInput {
    pub entry_date: String,
    pub journal_entry: Option<String>,
    pub gratitude: Option<String>,
    pub win: Option<String>,
    pub tension: Option<String>,
    pub single_word_feeling: Option<String>,
    pub latitude: Option<String>,
    pub longitude: Option<String>,
    pub city: Option<String>,
    pub state: Option<String>,
    pub country: Option<String>,
    pub feeling: i32,
    pub sleep_quality: i32,
    pub feeling_color_hex: String,
    pub drinks: i32,
    pub step_count: Option<i32>,
    pub walking_distance_meters: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub screen_time_seconds: Option<f64>,
    pub pickups: Option<i32>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncResponse {
    pub synced_at: String,
    pub count: usize,
}

async fn create_entries(
    State(state): State<AppState>,
    user: AuthUser,
    Json(body): Json<SyncUploadRequest>,
) -> Result<Json<SyncResponse>, AppError> {
    let scope = UserScope::new(&user, &state);
    let entries = &body.entries;

    if entries.is_empty() || entries.len() > 100 {
        return Err(AppError::Validation(
            "entries array must contain 1-100 items".to_string(),
        ));
    }

    // Validate each entry and collect parsed date/time fields
    let mut validated: Vec<ValidatedEntry> = Vec::with_capacity(entries.len());
    for entry in entries {
        validation::validate_entry_date(&entry.entry_date)?;
        let entry_date = validation::validate_entry_date_range(&entry.entry_date)?;
        let created_at = validation::validate_timestamp(&entry.created_at, "createdAt")?;
        let updated_at = validation::validate_timestamp(&entry.updated_at, "updatedAt")?;
        validation::validate_feeling(entry.feeling)?;
        validation::validate_sleep_quality(entry.sleep_quality)?;
        validation::validate_drinks(entry.drinks)?;

        // String length constraints — text fields: 20 KB max
        validation::validate_encrypted_field_length(
            &entry.journal_entry, "journalEntry", 20 * 1024,
        )?;
        validation::validate_encrypted_field_length(
            &entry.gratitude, "gratitude", 20 * 1024,
        )?;
        validation::validate_encrypted_field_length(
            &entry.win, "win", 20 * 1024,
        )?;
        validation::validate_encrypted_field_length(
            &entry.tension, "tension", 20 * 1024,
        )?;
        // singleWordFeeling: 1 KB max
        validation::validate_encrypted_field_length(
            &entry.single_word_feeling, "singleWordFeeling", 1024,
        )?;
        // Location fields: 1 KB max
        validation::validate_encrypted_field_length(&entry.city, "city", 1024)?;
        validation::validate_encrypted_field_length(&entry.state, "state", 1024)?;
        validation::validate_encrypted_field_length(&entry.country, "country", 1024)?;

        // Hex color format
        validation::validate_hex_color(&entry.feeling_color_hex)?;

        validated.push(ValidatedEntry {
            entry_date,
            created_at,
            updated_at,
        });
    }

    // Upsert user
    sqlx::query(
        "INSERT INTO users (clerk_user_id, last_sync_at) VALUES ($1, NOW())
         ON CONFLICT (clerk_user_id) DO UPDATE SET last_sync_at = NOW()",
    )
    .bind(&scope.user_id)
    .execute(&scope.pool)
    .await?;

    // Upsert entries using pre-validated date/time fields
    for (entry, v) in entries.iter().zip(validated.iter()) {
        sqlx::query(
            "INSERT INTO entries (
                user_id, entry_date, journal_entry, gratitude, win, tension,
                single_word_feeling, latitude, longitude, city, state, country,
                feeling, sleep_quality, feeling_color_hex, drinks,
                step_count, walking_distance_meters, sleep_hours,
                screen_time_seconds, pickups, created_at, updated_at
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
                $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23
            )
            ON CONFLICT (user_id, entry_date) DO UPDATE SET
                journal_entry = EXCLUDED.journal_entry,
                gratitude = EXCLUDED.gratitude,
                win = EXCLUDED.win,
                tension = EXCLUDED.tension,
                single_word_feeling = EXCLUDED.single_word_feeling,
                latitude = EXCLUDED.latitude,
                longitude = EXCLUDED.longitude,
                city = EXCLUDED.city,
                state = EXCLUDED.state,
                country = EXCLUDED.country,
                feeling = EXCLUDED.feeling,
                sleep_quality = EXCLUDED.sleep_quality,
                feeling_color_hex = EXCLUDED.feeling_color_hex,
                drinks = EXCLUDED.drinks,
                step_count = EXCLUDED.step_count,
                walking_distance_meters = EXCLUDED.walking_distance_meters,
                sleep_hours = EXCLUDED.sleep_hours,
                screen_time_seconds = EXCLUDED.screen_time_seconds,
                pickups = EXCLUDED.pickups,
                updated_at = EXCLUDED.updated_at",
        )
        .bind(&scope.user_id)
        .bind(v.entry_date)
        .bind(&entry.journal_entry)
        .bind(&entry.gratitude)
        .bind(&entry.win)
        .bind(&entry.tension)
        .bind(&entry.single_word_feeling)
        .bind(&entry.latitude)
        .bind(&entry.longitude)
        .bind(&entry.city)
        .bind(&entry.state)
        .bind(&entry.country)
        .bind(entry.feeling)
        .bind(entry.sleep_quality)
        .bind(&entry.feeling_color_hex)
        .bind(entry.drinks)
        .bind(entry.step_count)
        .bind(entry.walking_distance_meters)
        .bind(entry.sleep_hours)
        .bind(entry.screen_time_seconds)
        .bind(entry.pickups)
        .bind(v.created_at)
        .bind(v.updated_at)
        .execute(&scope.pool)
        .await?;
    }

    // Log to sync_log
    sqlx::query(
        "INSERT INTO sync_log (user_id, entries_pushed, entries_pulled) VALUES ($1, $2, 0)",
    )
    .bind(&scope.user_id)
    .bind(entries.len() as i32)
    .execute(&scope.pool)
    .await?;

    let synced_at = Utc::now()
        .to_rfc3339_opts(chrono::SecondsFormat::Millis, true);

    Ok(Json(SyncResponse {
        synced_at,
        count: entries.len(),
    }))
}

// --- GET /entries ---

#[derive(Debug, Deserialize)]
pub struct ListEntriesParams {
    pub since: Option<String>,
    pub cursor: Option<String>,
    pub limit: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ListEntriesResponse {
    pub entries: Vec<EntryResponse>,
    pub cursor: Option<String>,
}

async fn list_entries(
    State(state): State<AppState>,
    user: AuthUser,
    Query(params): Query<ListEntriesParams>,
) -> Result<Json<ListEntriesResponse>, AppError> {
    let scope = UserScope::new(&user, &state);
    let limit: i64 = params
        .limit
        .as_deref()
        .and_then(|l| l.parse::<i64>().ok())
        .unwrap_or(200)
        .min(200);

    // cursor takes priority over since
    let since_filter = params.cursor.as_deref().or(params.since.as_deref());

    let rows = if let Some(since) = since_filter {
        let since_dt = since
            .parse::<DateTime<Utc>>()
            .map_err(|e| AppError::Validation(format!("Invalid since/cursor timestamp: {e}")))?;

        sqlx::query_as::<_, crate::models::Entry>(
            "SELECT * FROM entries WHERE user_id = $1 AND updated_at > $2
             ORDER BY updated_at ASC LIMIT $3",
        )
        .bind(&scope.user_id)
        .bind(since_dt)
        .bind(limit)
        .fetch_all(&scope.pool)
        .await?
    } else {
        sqlx::query_as::<_, crate::models::Entry>(
            "SELECT * FROM entries WHERE user_id = $1
             ORDER BY updated_at ASC LIMIT $2",
        )
        .bind(&scope.user_id)
        .bind(limit)
        .fetch_all(&scope.pool)
        .await?
    };

    let next_cursor = if rows.len() as i64 == limit {
        rows.last().map(|e| {
            e.updated_at
                .to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
        })
    } else {
        None
    };

    let entries: Vec<EntryResponse> = rows.into_iter().map(EntryResponse::from).collect();

    Ok(Json(ListEntriesResponse {
        entries,
        cursor: next_cursor,
    }))
}

// --- DELETE /entries/:date ---

#[derive(Debug, Serialize)]
pub struct DeleteResponse {
    pub deleted: bool,
}

async fn delete_entry(
    State(state): State<AppState>,
    user: AuthUser,
    Path(date): Path<String>,
) -> Result<Json<DeleteResponse>, AppError> {
    let scope = UserScope::new(&user, &state);
    sqlx::query("DELETE FROM entries WHERE user_id = $1 AND entry_date = $2")
        .bind(&scope.user_id)
        .bind(&date)
        .execute(&scope.pool)
        .await?;

    Ok(Json(DeleteResponse { deleted: true }))
}
