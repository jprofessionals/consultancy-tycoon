use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Player {
    pub id: Uuid,
    pub display_name: String,
    pub passphrase: String,
    pub username: Option<String>,
    pub password_hash: Option<String>,
    pub show_on_leaderboard: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreatePlayerRequest {
    pub display_name: String,
}

#[derive(Debug, Serialize)]
pub struct CreatePlayerResponse {
    pub id: Uuid,
    pub passphrase: String,
    pub token: String,
}

#[derive(Debug, Deserialize)]
pub struct RecoverRequest {
    pub passphrase: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub id: Uuid,
    pub display_name: String,
    pub token: String,
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdatePlayerRequest {
    pub display_name: Option<String>,
    pub show_on_leaderboard: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct ScoreSubmission {
    pub total_money_earned: f64,
    pub reputation: f64,
    pub skill_levels_sum: i32,
    pub consultants_count: i32,
    pub ai_tool_tiers_sum: i32,
    pub manual_tasks_completed: i32,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct LeaderboardEntry {
    pub rank: i64,
    pub display_name: String,
    pub score: f64,
    pub total_money_earned: f64,
    pub reputation: f64,
    pub skill_levels_sum: i32,
    pub consultants_count: i32,
    pub ai_tool_tiers_sum: i32,
    pub manual_tasks_completed: i32,
}

#[derive(Debug, Serialize)]
pub struct LeaderboardResponse {
    pub entries: Vec<LeaderboardEntry>,
    pub player_rank: Option<i64>,
    pub player_score: Option<f64>,
}

#[derive(Debug, Deserialize)]
pub struct SaveUpload {
    pub save_data: serde_json::Value,
    pub version: i32,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct SaveDownload {
    pub save_data: serde_json::Value,
    pub version: i32,
    pub updated_at: DateTime<Utc>,
}
