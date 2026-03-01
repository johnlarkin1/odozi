use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Entry {
    pub id: i32,
    pub user_id: String,
    pub entry_date: NaiveDate,
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
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Response shape for GET /entries — omits id and user_id per API contract.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EntryResponse {
    pub entry_date: NaiveDate,
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
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<Entry> for EntryResponse {
    fn from(e: Entry) -> Self {
        Self {
            entry_date: e.entry_date,
            journal_entry: e.journal_entry,
            gratitude: e.gratitude,
            win: e.win,
            tension: e.tension,
            single_word_feeling: e.single_word_feeling,
            latitude: e.latitude,
            longitude: e.longitude,
            city: e.city,
            state: e.state,
            country: e.country,
            feeling: e.feeling,
            sleep_quality: e.sleep_quality,
            feeling_color_hex: e.feeling_color_hex,
            drinks: e.drinks,
            step_count: e.step_count,
            walking_distance_meters: e.walking_distance_meters,
            sleep_hours: e.sleep_hours,
            screen_time_seconds: e.screen_time_seconds,
            pickups: e.pickups,
            created_at: e.created_at,
            updated_at: e.updated_at,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct User {
    pub clerk_user_id: String,
    pub email: Option<String>,
    pub created_at: DateTime<Utc>,
    pub last_sync_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct EncryptedKeyBackup {
    pub id: i32,
    pub user_id: String,
    pub encrypted_key_data: String,
    pub key_derivation_salt: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct SyncLog {
    pub id: i32,
    pub user_id: String,
    pub device_id: Option<String>,
    pub entries_pushed: Option<i32>,
    pub entries_pulled: Option<i32>,
    pub created_at: DateTime<Utc>,
}
