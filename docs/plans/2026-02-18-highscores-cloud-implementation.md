# Highscores & Cloud Saves Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add composite scoring, online leaderboard, cloud save sync, and player identity to Consultancy Tycoon.

**Architecture:** Two-part system: (1) Godot client tracks score components, syncs saves/scores via HTTP to (2) a Rust backend (Axum + PostgreSQL) running on the same VM. Player identity uses auto-generated passphrases with optional username/password upgrade.

**Tech Stack:** Godot 4.6 / GDScript, Rust / Axum / sqlx / PostgreSQL, JWT for auth tokens

**Design doc:** `docs/plans/2026-02-18-highscores-cloud-design.md`

---

### Task 1: Add Score Tracking Fields to GameState

**Files:**
- Modify: `src/autoload/game_state.gd:1-13` (add new fields)
- Modify: `src/autoload/game_state.gd:17-21` (update add_money)
- Test: `test/unit/test_game_state.gd`

**Step 1: Write the failing tests**

Add to `test/unit/test_game_state.gd`:

```gdscript
func test_initial_total_money_earned_is_zero():
	assert_eq(state.total_money_earned, 0.0)

func test_add_money_tracks_total_earned():
	state.add_money(100.0)
	state.add_money(50.0)
	assert_eq(state.total_money_earned, 150.0)

func test_spending_does_not_reduce_total_earned():
	state.add_money(200.0)
	state.spend_money(100.0)
	assert_eq(state.total_money_earned, 200.0)

func test_negative_add_money_does_not_track_earned():
	state.add_money(100.0)
	state.add_money(-50.0)
	assert_eq(state.total_money_earned, 100.0)

func test_initial_manual_tasks_completed_is_zero():
	assert_eq(state.total_manual_tasks_completed, 0)

func test_increment_manual_tasks():
	state.increment_manual_tasks()
	state.increment_manual_tasks()
	assert_eq(state.total_manual_tasks_completed, 2)

func test_initial_player_name_empty():
	assert_eq(state.player_name, "")
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: 7 failures — fields and methods don't exist yet.

**Step 3: Write minimal implementation**

In `src/autoload/game_state.gd`, add new fields after line 12 (`var active_rentals`):

```gdscript
var total_money_earned: float = 0.0
var total_manual_tasks_completed: int = 0
var player_name: String = ""
```

Update `add_money()` to track lifetime earnings:

```gdscript
func add_money(amount: float) -> void:
	money += amount
	if amount > 0:
		total_money_earned += amount
	var bus = _get_event_bus()
	if bus:
		bus.money_changed.emit(money)
```

Add `increment_manual_tasks()` method (after `add_reputation()`):

```gdscript
func increment_manual_tasks() -> void:
	total_manual_tasks_completed += 1
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests pass (176 existing + 7 new = 183).

**Step 5: Commit**

```bash
git add src/autoload/game_state.gd test/unit/test_game_state.gd
git commit -m "feat: add score tracking fields to GameState"
```

---

### Task 2: Serialize Score Fields in SaveManager

**Files:**
- Modify: `src/systems/save_manager.gd:60-68` (add to _build_save_dict game_state section)
- Modify: `src/systems/save_manager.gd:105-112` (add to apply_save restore section)
- Modify: `src/systems/save_manager.gd:373-450` (update create_test_save)
- Test: `test/unit/test_save_load.gd`

**Step 1: Write the failing tests**

Add to `test/unit/test_save_load.gd`:

```gdscript
func test_round_trip_score_fields():
	state.total_money_earned = 50000.0
	state.total_manual_tasks_completed = 42
	state.player_name = "TestPlayer"
	save_mgr.save_game(_runtime(), state)

	state.total_money_earned = 0.0
	state.total_manual_tasks_completed = 0
	state.player_name = ""

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_almost_eq(state.total_money_earned, 50000.0, 0.01)
	assert_eq(state.total_manual_tasks_completed, 42)
	assert_eq(state.player_name, "TestPlayer")

func test_backward_compat_missing_score_fields():
	# Old save without score fields should default gracefully
	var old_data: Dictionary = {
		"version": 1,
		"timestamp": 12345,
		"game_state": {
			"money": 1000.0,
			"reputation": 5.0,
			"skills": {},
			"ai_tools": {},
			"office_unlocked": false,
			"claimed_easter_eggs": {},
		},
		"consultants": [],
		"active_assignments": [],
		"active_rentals": [],
		"tabs": [],
		"focused_index": 0,
		"game_started": true,
	}
	var json_string = JSON.stringify(old_data, "\t")
	var file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_eq(state.total_money_earned, 0.0, "Missing field should default to 0")
	assert_eq(state.total_manual_tasks_completed, 0, "Missing field should default to 0")
	assert_eq(state.player_name, "", "Missing field should default to empty")
```

**Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: 2 failures — new fields not serialized/deserialized yet.

**Step 3: Write minimal implementation**

In `_build_save_dict()`, add to the `game_state` dictionary (after `desk_capacity`):

```gdscript
"total_money_earned": gs_node.total_money_earned,
"total_manual_tasks_completed": gs_node.total_manual_tasks_completed,
"player_name": gs_node.player_name,
```

In `apply_save()`, add after the `desk_capacity` restore line:

```gdscript
gs_node.total_money_earned = float(gs.get("total_money_earned", 0.0))
gs_node.total_manual_tasks_completed = int(gs.get("total_manual_tasks_completed", 0))
gs_node.player_name = str(gs.get("player_name", ""))
```

In `create_test_save()`, add to the `game_state` dictionary:

```gdscript
"total_money_earned": 350000.0,
"total_manual_tasks_completed": 75,
"player_name": "DevPlayer",
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests pass (183 + 2 = 185).

**Step 5: Commit**

```bash
git add src/systems/save_manager.gd test/unit/test_save_load.gd
git commit -m "feat: serialize score tracking fields in save system"
```

---

### Task 3: Wire Manual Task Completion Tracking

**Files:**
- Modify: `src/main.gd:763-770` (_on_tab_task_done — increment counter for player-completed tasks)
- Test: `test/unit/test_game_state.gd` (already covered in Task 1)

The distinction between player-completed and AI-completed tasks:
- `_on_tab_task_done` is called for ALL completed tasks (player and AI)
- We need to distinguish. The simplest approach: track whether the focused tab completed a task while the player was at the monitor.

**Step 1: Write the failing test**

Add to `test/unit/test_game_state.gd`:

```gdscript
func test_get_score_components():
	state.total_money_earned = 10000.0
	state.reputation = 20.0
	state.skills = {"javascript": 3, "python": 2}
	state.ai_tools = {"auto_writer": 2, "auto_reviewer": 1}
	state.total_manual_tasks_completed = 10
	var c1 = ConsultantData.new()
	c1.id = "score_1"
	state.consultants.append(c1)
	var c2 = ConsultantData.new()
	c2.id = "score_2"
	state.consultants.append(c2)

	var components = state.get_score_components()

	assert_almost_eq(components["total_money_earned"], 10000.0, 0.01)
	assert_almost_eq(components["reputation"], 20.0, 0.01)
	assert_eq(components["skill_levels_sum"], 5)
	assert_eq(components["consultants_count"], 2)
	assert_eq(components["ai_tool_tiers_sum"], 3)
	assert_eq(components["manual_tasks_completed"], 10)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: FAIL — `get_score_components()` doesn't exist.

**Step 3: Write minimal implementation**

Add to `src/autoload/game_state.gd` (after `increment_manual_tasks()`):

```gdscript
func get_score_components() -> Dictionary:
	var skill_sum: int = 0
	for level in skills.values():
		skill_sum += int(level)
	var ai_sum: int = 0
	for tier in ai_tools.values():
		ai_sum += int(tier)
	return {
		"total_money_earned": total_money_earned,
		"reputation": reputation,
		"skill_levels_sum": skill_sum,
		"consultants_count": consultants.size(),
		"ai_tool_tiers_sum": ai_sum,
		"manual_tasks_completed": total_manual_tasks_completed,
	}
```

In `src/main.gd`, update `_on_tab_task_done()` to track manual completions. A task is "manual" if it was on the focused tab while the player was at the monitor:

```gdscript
func _on_tab_task_done(task: CodingTask, tab: CodingTab):
	# Track manual task completion (focused tab while at monitor)
	var tab_idx = ide.tabs.find(tab)
	if tab_idx == ide.get_focused_index() and state == DeskState.ZOOMED_TO_MONITOR:
		GameState.increment_manual_tasks()
	tab.task_index += 1
	# ... rest unchanged
```

**Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All tests pass (186).

**Step 5: Commit**

```bash
git add src/autoload/game_state.gd src/main.gd
git commit -m "feat: track manual task completions and score components"
```

---

### Task 4: Scaffold Rust Backend Project

**Files:**
- Create: `backend/Cargo.toml`
- Create: `backend/src/main.rs`
- Create: `backend/.env.example`
- Create: `backend/migrations/001_initial.sql`

**Step 1: Initialize Cargo project**

```bash
cd /home/lars/Prosjekter/consultancy-tycoon
mkdir -p backend
cd backend
cargo init --name consultancy-tycoon-api
```

**Step 2: Add dependencies to `Cargo.toml`**

```toml
[package]
name = "consultancy-tycoon-api"
version = "0.1.0"
edition = "2024"

[dependencies]
axum = "0.8"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid", "chrono"] }
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
jsonwebtoken = "9"
argon2 = "0.5"
tower-http = { version = "0.6", features = ["cors"] }
rand = "0.9"
```

**Step 3: Create database migration**

Create `backend/migrations/001_initial.sql`:

```sql
CREATE TABLE players (
    id UUID PRIMARY KEY,
    display_name TEXT NOT NULL,
    passphrase TEXT NOT NULL UNIQUE,
    username TEXT UNIQUE,
    password_hash TEXT,
    show_on_leaderboard BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE score_components (
    player_id UUID PRIMARY KEY REFERENCES players(id),
    total_money_earned DOUBLE PRECISION NOT NULL DEFAULT 0,
    reputation DOUBLE PRECISION NOT NULL DEFAULT 0,
    skill_levels_sum INTEGER NOT NULL DEFAULT 0,
    consultants_count INTEGER NOT NULL DEFAULT 0,
    ai_tool_tiers_sum INTEGER NOT NULL DEFAULT 0,
    manual_tasks_completed INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE saves (
    player_id UUID PRIMARY KEY REFERENCES players(id),
    save_data JSONB NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_leaderboard ON score_components (
    (total_money_earned * 1.0 + reputation * 500 + skill_levels_sum * 100
     + consultants_count * 250 + ai_tool_tiers_sum * 150 + manual_tasks_completed * 50) DESC
) WHERE TRUE;
```

Note: The index expression calculates the composite score for efficient leaderboard queries. If weights change, recreate the index.

**Step 4: Create `.env.example`**

```
DATABASE_URL=postgres://user:password@localhost/consultancy_tycoon
JWT_SECRET=change-me-to-a-random-string
LISTEN_ADDR=127.0.0.1:3080
```

**Step 5: Write minimal `src/main.rs`**

```rust
use axum::{Router, routing::get};
use sqlx::postgres::PgPoolOptions;
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;

mod db;
mod handlers;
mod models;
mod auth;

#[derive(Clone)]
pub struct AppState {
    pub db: sqlx::PgPool,
    pub jwt_secret: String,
}

#[tokio::main]
async fn main() {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    let jwt_secret = std::env::var("JWT_SECRET")
        .expect("JWT_SECRET must be set");
    let listen_addr: SocketAddr = std::env::var("LISTEN_ADDR")
        .unwrap_or_else(|_| "127.0.0.1:3080".to_string())
        .parse()
        .expect("Invalid LISTEN_ADDR");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to connect to database");

    let state = AppState {
        db: pool,
        jwt_secret,
    };

    let app = Router::new()
        .route("/api/health", get(|| async { "ok" }))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(listen_addr).await.unwrap();
    println!("Listening on {}", listen_addr);
    axum::serve(listener, app).await.unwrap();
}
```

**Step 6: Create stub module files**

Create `backend/src/db.rs`, `backend/src/handlers.rs`, `backend/src/models.rs`, `backend/src/auth.rs` as empty files (or with `// TODO` comments).

**Step 7: Verify it compiles**

```bash
cd backend && cargo check
```

**Step 8: Commit**

```bash
git add backend/
git commit -m "feat: scaffold Rust backend with Axum + sqlx + PostgreSQL"
```

---

### Task 5: Implement Models and Auth Module

**Files:**
- Create: `backend/src/models.rs`
- Create: `backend/src/auth.rs`

**Step 1: Write models**

`backend/src/models.rs`:

```rust
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

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct ScoreComponents {
    pub player_id: Uuid,
    pub total_money_earned: f64,
    pub reputation: f64,
    pub skill_levels_sum: i32,
    pub consultants_count: i32,
    pub ai_tool_tiers_sum: i32,
    pub manual_tasks_completed: i32,
    pub updated_at: DateTime<Utc>,
}

// API request/response types

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

#[derive(Debug, Serialize)]
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

#[derive(Debug, Serialize)]
pub struct SaveDownload {
    pub save_data: serde_json::Value,
    pub version: i32,
    pub updated_at: DateTime<Utc>,
}
```

**Step 2: Write auth module**

`backend/src/auth.rs`:

```rust
use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,  // player id
    pub exp: usize, // expiry (unix timestamp)
}

pub fn create_token(player_id: Uuid, secret: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let expiry = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::days(365))
        .unwrap()
        .timestamp() as usize;

    let claims = Claims {
        sub: player_id,
        exp: expiry,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
}

pub fn verify_token(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )?;
    Ok(token_data.claims)
}

/// Extractor that validates the Bearer token and returns the player UUID.
pub struct AuthPlayer(pub Uuid);

impl<S> FromRequestParts<S> for AuthPlayer
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or(StatusCode::UNAUTHORIZED)?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or(StatusCode::UNAUTHORIZED)?;

        // Get JWT secret from extensions (set by middleware)
        let secret = parts
            .extensions
            .get::<JwtSecret>()
            .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

        let claims = verify_token(token, &secret.0)
            .map_err(|_| StatusCode::UNAUTHORIZED)?;

        Ok(AuthPlayer(claims.sub))
    }
}

#[derive(Clone)]
pub struct JwtSecret(pub String);
```

**Step 3: Verify it compiles**

```bash
cd backend && cargo check
```

**Step 4: Commit**

```bash
git add backend/src/models.rs backend/src/auth.rs
git commit -m "feat: add models and JWT auth module for backend"
```

---

### Task 6: Implement Database Layer

**Files:**
- Create: `backend/src/db.rs`

**Step 1: Write database functions**

`backend/src/db.rs`:

```rust
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::*;

const SCORE_FORMULA: &str =
    "total_money_earned * 1.0 + reputation * 500 + skill_levels_sum * 100 \
     + consultants_count * 250 + ai_tool_tiers_sum * 150 + manual_tasks_completed * 50";

pub async fn create_player(
    pool: &PgPool,
    id: Uuid,
    display_name: &str,
    passphrase: &str,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query(
        "INSERT INTO players (id, display_name, passphrase) VALUES ($1, $2, $3)"
    )
    .bind(id)
    .bind(display_name)
    .bind(passphrase)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        "INSERT INTO score_components (player_id) VALUES ($1)"
    )
    .bind(id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn find_player_by_passphrase(
    pool: &PgPool,
    passphrase: &str,
) -> Result<Option<Player>, sqlx::Error> {
    sqlx::query_as::<_, Player>(
        "SELECT * FROM players WHERE passphrase = $1"
    )
    .bind(passphrase)
    .fetch_optional(pool)
    .await
}

pub async fn find_player_by_username(
    pool: &PgPool,
    username: &str,
) -> Result<Option<Player>, sqlx::Error> {
    sqlx::query_as::<_, Player>(
        "SELECT * FROM players WHERE username = $1"
    )
    .bind(username)
    .fetch_optional(pool)
    .await
}

pub async fn update_player(
    pool: &PgPool,
    player_id: Uuid,
    display_name: Option<&str>,
    show_on_leaderboard: Option<bool>,
) -> Result<(), sqlx::Error> {
    if let Some(name) = display_name {
        sqlx::query("UPDATE players SET display_name = $1, updated_at = NOW() WHERE id = $2")
            .bind(name)
            .bind(player_id)
            .execute(pool)
            .await?;
    }
    if let Some(show) = show_on_leaderboard {
        sqlx::query("UPDATE players SET show_on_leaderboard = $1, updated_at = NOW() WHERE id = $2")
            .bind(show)
            .bind(player_id)
            .execute(pool)
            .await?;
    }
    Ok(())
}

pub async fn set_credentials(
    pool: &PgPool,
    player_id: Uuid,
    username: &str,
    password_hash: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE players SET username = $1, password_hash = $2, updated_at = NOW() WHERE id = $3"
    )
    .bind(username)
    .bind(password_hash)
    .bind(player_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn upsert_scores(
    pool: &PgPool,
    player_id: Uuid,
    scores: &ScoreSubmission,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO score_components (player_id, total_money_earned, reputation, \
         skill_levels_sum, consultants_count, ai_tool_tiers_sum, manual_tasks_completed, updated_at) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW()) \
         ON CONFLICT (player_id) DO UPDATE SET \
         total_money_earned = GREATEST(score_components.total_money_earned, $2), \
         reputation = GREATEST(score_components.reputation, $3), \
         skill_levels_sum = GREATEST(score_components.skill_levels_sum, $4), \
         consultants_count = GREATEST(score_components.consultants_count, $5), \
         ai_tool_tiers_sum = GREATEST(score_components.ai_tool_tiers_sum, $6), \
         manual_tasks_completed = GREATEST(score_components.manual_tasks_completed, $7), \
         updated_at = NOW()"
    )
    .bind(player_id)
    .bind(scores.total_money_earned)
    .bind(scores.reputation)
    .bind(scores.skill_levels_sum)
    .bind(scores.consultants_count)
    .bind(scores.ai_tool_tiers_sum)
    .bind(scores.manual_tasks_completed)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_leaderboard(
    pool: &PgPool,
    limit: i64,
) -> Result<Vec<LeaderboardEntry>, sqlx::Error> {
    let query = format!(
        "SELECT p.display_name, s.total_money_earned, s.reputation, \
         s.skill_levels_sum, s.consultants_count, s.ai_tool_tiers_sum, \
         s.manual_tasks_completed, \
         ({score}) as score, \
         ROW_NUMBER() OVER (ORDER BY ({score}) DESC) as rank \
         FROM score_components s \
         JOIN players p ON p.id = s.player_id \
         WHERE p.show_on_leaderboard = true \
         ORDER BY ({score}) DESC \
         LIMIT $1",
        score = SCORE_FORMULA
    );

    sqlx::query_as::<_, LeaderboardEntry>(&query)
        .bind(limit)
        .fetch_all(pool)
        .await
}

pub async fn get_player_rank(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Option<(i64, f64)>, sqlx::Error> {
    let query = format!(
        "SELECT rank, score FROM ( \
         SELECT s.player_id, \
         ({score}) as score, \
         ROW_NUMBER() OVER (ORDER BY ({score}) DESC) as rank \
         FROM score_components s \
         JOIN players p ON p.id = s.player_id \
         WHERE p.show_on_leaderboard = true \
         ) ranked WHERE player_id = $1",
        score = SCORE_FORMULA
    );

    let row: Option<(i64, f64)> = sqlx::query_as(&query)
        .bind(player_id)
        .fetch_optional(pool)
        .await?;
    Ok(row)
}

pub async fn upsert_save(
    pool: &PgPool,
    player_id: Uuid,
    save_data: &serde_json::Value,
    version: i32,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO saves (player_id, save_data, version, updated_at) \
         VALUES ($1, $2, $3, NOW()) \
         ON CONFLICT (player_id) DO UPDATE SET \
         save_data = $2, version = $3, updated_at = NOW()"
    )
    .bind(player_id)
    .bind(save_data)
    .bind(version)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_save(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Option<SaveDownload>, sqlx::Error> {
    sqlx::query_as::<_, SaveDownload>(
        "SELECT save_data, version, updated_at FROM saves WHERE player_id = $1"
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await
}
```

Note: `LeaderboardEntry` and `SaveDownload` need `sqlx::FromRow` derive added in models.rs.

**Step 2: Verify it compiles**

```bash
cd backend && cargo check
```

**Step 3: Commit**

```bash
git add backend/src/db.rs
git commit -m "feat: implement database layer for players, scores, saves"
```

---

### Task 7: Implement API Handlers

**Files:**
- Create: `backend/src/handlers.rs`
- Modify: `backend/src/main.rs` (wire routes)

**Step 1: Write handlers**

`backend/src/handlers.rs`:

```rust
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use uuid::Uuid;

use crate::auth::{create_token, AuthPlayer};
use crate::db;
use crate::models::*;
use crate::AppState;

// Word lists for passphrase generation
const ADJECTIVES: &[&str] = &[
    "BRAVE", "CALM", "DARK", "FAST", "GOLD", "HAPPY", "ICY", "KEEN",
    "LOUD", "MILD", "NEAT", "ODD", "PINK", "QUICK", "RED", "SAFE",
    "TALL", "VAST", "WARM", "ZESTY",
];

const NOUNS: &[&str] = &[
    "BEAR", "CAT", "DEER", "ELK", "FOX", "GOAT", "HAWK", "IBIS",
    "JAY", "KITE", "LION", "MOON", "NEWT", "OWL", "PIKE", "QUAIL",
    "ROSE", "STAR", "TOAD", "WOLF",
];

fn generate_passphrase() -> String {
    use rand::Rng;
    let mut rng = rand::rng();
    let adj = ADJECTIVES[rng.random_range(0..ADJECTIVES.len())];
    let noun = NOUNS[rng.random_range(0..NOUNS.len())];
    let num: u32 = rng.random_range(10..100);
    format!("{}-{}-{}", adj, noun, num)
}

pub async fn create_player(
    State(state): State<AppState>,
    Json(req): Json<CreatePlayerRequest>,
) -> Result<Json<CreatePlayerResponse>, StatusCode> {
    let id = Uuid::new_v4();
    let passphrase = generate_passphrase();

    db::create_player(&state.db, id, &req.display_name, &passphrase)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let token = create_token(id, &state.jwt_secret)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(CreatePlayerResponse {
        id,
        passphrase,
        token,
    }))
}

pub async fn recover_player(
    State(state): State<AppState>,
    Json(req): Json<RecoverRequest>,
) -> Result<Json<AuthResponse>, StatusCode> {
    let player = db::find_player_by_passphrase(&state.db, &req.passphrase)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let token = create_token(player.id, &state.jwt_secret)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(AuthResponse {
        id: player.id,
        display_name: player.display_name,
        token,
    }))
}

pub async fn register(
    State(state): State<AppState>,
    auth: AuthPlayer,
    Json(req): Json<RegisterRequest>,
) -> Result<StatusCode, StatusCode> {
    // Check username not taken
    let existing = db::find_player_by_username(&state.db, &req.username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    if existing.is_some() {
        return Err(StatusCode::CONFLICT);
    }

    let password_hash = argon2::hash_encoded(
        req.password.as_bytes(),
        Uuid::new_v4().as_bytes(),
        &argon2::Config::default(),
    )
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    db::set_credentials(&state.db, auth.0, &req.username, &password_hash)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, StatusCode> {
    let player = db::find_player_by_username(&state.db, &req.username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let hash = player.password_hash.as_deref().ok_or(StatusCode::NOT_FOUND)?;

    let valid = argon2::verify_encoded(hash, req.password.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if !valid {
        return Err(StatusCode::UNAUTHORIZED);
    }

    let token = create_token(player.id, &state.jwt_secret)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(AuthResponse {
        id: player.id,
        display_name: player.display_name,
        token,
    }))
}

pub async fn update_player(
    State(state): State<AppState>,
    auth: AuthPlayer,
    Json(req): Json<UpdatePlayerRequest>,
) -> Result<StatusCode, StatusCode> {
    db::update_player(
        &state.db,
        auth.0,
        req.display_name.as_deref(),
        req.show_on_leaderboard,
    )
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

pub async fn submit_scores(
    State(state): State<AppState>,
    auth: AuthPlayer,
    Json(scores): Json<ScoreSubmission>,
) -> Result<StatusCode, StatusCode> {
    db::upsert_scores(&state.db, auth.0, &scores)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

pub async fn get_leaderboard(
    State(state): State<AppState>,
    auth: Option<AuthPlayer>,
) -> Result<Json<LeaderboardResponse>, StatusCode> {
    let entries = db::get_leaderboard(&state.db, 50)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (player_rank, player_score) = if let Some(AuthPlayer(pid)) = auth {
        db::get_player_rank(&state.db, pid)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
            .map(|(r, s)| (Some(r), Some(s)))
            .unwrap_or((None, None))
    } else {
        (None, None)
    };

    Ok(Json(LeaderboardResponse {
        entries,
        player_rank,
        player_score,
    }))
}

pub async fn upload_save(
    State(state): State<AppState>,
    auth: AuthPlayer,
    Json(save): Json<SaveUpload>,
) -> Result<StatusCode, StatusCode> {
    db::upsert_save(&state.db, auth.0, &save.save_data, save.version)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

pub async fn download_save(
    State(state): State<AppState>,
    auth: AuthPlayer,
) -> Result<Json<SaveDownload>, StatusCode> {
    let save = db::get_save(&state.db, auth.0)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(save))
}
```

**Step 2: Wire routes in `main.rs`**

Update `backend/src/main.rs` to add all routes:

```rust
use axum::{Router, routing::{get, post, put, patch}, middleware};

// ... (keep existing code, update the router)

let app = Router::new()
    .route("/api/health", get(|| async { "ok" }))
    .route("/api/players", post(handlers::create_player))
    .route("/api/players/recover", post(handlers::recover_player))
    .route("/api/players/register", post(handlers::register))
    .route("/api/players/login", post(handlers::login))
    .route("/api/players/me", patch(handlers::update_player))
    .route("/api/scores", put(handlers::submit_scores))
    .route("/api/leaderboard", get(handlers::get_leaderboard))
    .route("/api/saves", put(handlers::upload_save))
    .route("/api/saves", get(handlers::download_save))
    .layer(CorsLayer::permissive())
    .layer(middleware::from_fn_with_state(
        state.clone(),
        |state: State<AppState>, mut req: axum::extract::Request, next: middleware::Next| async move {
            req.extensions_mut().insert(auth::JwtSecret(state.jwt_secret.clone()));
            next.run(req).await
        },
    ))
    .with_state(state);
```

**Step 3: Verify it compiles**

```bash
cd backend && cargo check
```

Note: The implementer may need to adjust imports and fix compiler errors. The `argon2` crate API may differ from what's shown — check latest docs. The `LeaderboardEntry` needs `sqlx::FromRow` (already noted in Task 6).

**Step 4: Commit**

```bash
git add backend/src/handlers.rs backend/src/main.rs
git commit -m "feat: implement all API handlers and wire routes"
```

---

### Task 8: Implement CloudManager Autoload (Godot)

**Files:**
- Create: `src/autoload/cloud_manager.gd`
- Modify: `project.godot:18-23` (add CloudManager autoload)

**Step 1: Create CloudManager**

`src/autoload/cloud_manager.gd`:

```gdscript
extends Node

const AUTH_PATH = "user://cloud_auth.json"
const DEFAULT_BASE_URL = "https://tycoon.jpro.dev"

var base_url: String = DEFAULT_BASE_URL
var player_id: String = ""
var auth_token: String = ""
var passphrase: String = ""
var _syncing: bool = false

signal player_created(player_id: String, passphrase: String)
signal player_recovered(player_id: String)
signal sync_completed(success: bool)
signal leaderboard_fetched(data: Dictionary)
signal cloud_save_available(cloud_timestamp: int)

func _ready():
	_load_auth()

# ── Auth persistence ──

func _load_auth():
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var file = FileAccess.open(AUTH_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		player_id = str(json.data.get("player_id", ""))
		auth_token = str(json.data.get("auth_token", ""))
		passphrase = str(json.data.get("passphrase", ""))

func _save_auth():
	var data = {
		"player_id": player_id,
		"auth_token": auth_token,
		"passphrase": passphrase,
	}
	var file = FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.Module&&Module.FS&&Module.FS.syncfs)Module.FS.syncfs(false,function(e){});")

func is_authenticated() -> bool:
	return player_id != "" and auth_token != ""

# ── Player creation ──

func create_player(display_name: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"display_name": display_name})
	http.request(base_url + "/api/players", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	var response_code = result[1]
	if response_code == 200 or response_code == 201:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			passphrase = str(json.data.get("passphrase", ""))
			_save_auth()
			player_created.emit(player_id, passphrase)

func recover_player(input_passphrase: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"passphrase": input_passphrase})
	http.request(base_url + "/api/players/recover", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	var response_code = result[1]
	if response_code == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			var name = str(json.data.get("display_name", ""))
			_save_auth()
			player_recovered.emit(player_id)

# ── Score submission ──

func submit_scores(components: Dictionary) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify(components)
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/scores", headers, HTTPClient.METHOD_PUT, body)
	var result = await http.request_completed
	http.queue_free()

# ── Cloud save ──

func upload_save(save_data: Dictionary) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"save_data": save_data, "version": 1})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/saves", headers, HTTPClient.METHOD_PUT, body)
	var result = await http.request_completed
	http.queue_free()

func download_save() -> Dictionary:
	if not is_authenticated():
		return {}
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/saves", headers, HTTPClient.METHOD_GET)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			return json.data
	return {}

# ── Leaderboard ──

func fetch_leaderboard() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = []
	if is_authenticated():
		headers = ["Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/leaderboard", headers, HTTPClient.METHOD_GET)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			leaderboard_fetched.emit(json.data)

# ── Sync (called from autosave timer) ──

func sync(runtime_state: Dictionary, game_state: Node) -> void:
	if not is_authenticated() or _syncing:
		return
	_syncing = true
	# Submit scores
	var components = game_state.get_score_components()
	submit_scores(components)
	# Upload save (build dict like SaveManager does, but we pass the raw dict)
	upload_save(runtime_state)
	_syncing = false
	sync_completed.emit(true)

# ── Profile update ──

func update_display_name(new_name: String) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"display_name": new_name})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/me", headers, HTTPClient.METHOD_PATCH, body)
	var result = await http.request_completed
	http.queue_free()

func set_leaderboard_visibility(visible: bool) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"show_on_leaderboard": visible})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/me", headers, HTTPClient.METHOD_PATCH, body)
	var result = await http.request_completed
	http.queue_free()

# ── Account upgrade ──

func register_account(username: String, password: String) -> bool:
	if not is_authenticated():
		return false
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"username": username, "password": password})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/register", headers, HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	return result[1] == 200

func login(username: String, password: String) -> bool:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"username": username, "password": password})
	http.request(base_url + "/api/players/login", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			_save_auth()
			return true
	return false
```

**Step 2: Register autoload in project.godot**

Add after the SaveManager line:

```ini
CloudManager="*res://src/autoload/cloud_manager.gd"
```

**Step 3: Run `godot --headless --import` to register**

```bash
godot --headless --import
```

**Step 4: Run existing tests to make sure nothing breaks**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All 186 tests pass (CloudManager as autoload won't affect tests since they don't use it).

**Step 5: Commit**

```bash
git add src/autoload/cloud_manager.gd project.godot
git commit -m "feat: add CloudManager autoload for server communication"
```

---

### Task 9: Wire Cloud Sync to Autosave

**Files:**
- Modify: `src/main.gd:539-543` (_on_autosave — add cloud sync)
- Modify: `src/main.gd:391-407` (_on_start_game — create player on new game)

**Step 1: Update _on_autosave to sync with cloud**

In `src/main.gd`, update `_on_autosave()`:

```gdscript
func _on_autosave():
	if not _game_started:
		return
	var runtime = _collect_runtime_state()
	SaveManager.save_game(runtime)
	# Cloud sync (best-effort, non-blocking)
	if CloudManager.is_authenticated():
		var save_dict = SaveManager._build_save_dict(runtime, GameState)
		CloudManager.submit_scores(GameState.get_score_components())
		CloudManager.upload_save(save_dict)
```

**Step 2: Update _on_start_game for player creation**

The welcome screen will be updated in Task 11 to add name entry. For now, wire the flow:

In `_on_start_game()`, after starting timers, add cloud sync for loaded saves:

```gdscript
# After: autosave_timer.start()
# Sync with cloud on game start
if CloudManager.is_authenticated():
	var runtime = _collect_runtime_state()
	var save_dict = SaveManager._build_save_dict(runtime, GameState)
	CloudManager.submit_scores(GameState.get_score_components())
	CloudManager.upload_save(save_dict)
```

**Step 3: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass. CloudManager calls are no-ops in tests (not authenticated).

**Step 4: Commit**

```bash
git add src/main.gd
git commit -m "feat: wire cloud sync to autosave timer and game start"
```

---

### Task 10: Build Leaderboard Panel

**Files:**
- Create: `src/ui/leaderboard_panel.tscn` (minimal scene)
- Create: `src/ui/leaderboard_panel.gd`

**Step 1: Create minimal .tscn file**

`src/ui/leaderboard_panel.tscn`: A PanelContainer root with script attached.

**Step 2: Write leaderboard panel script**

`src/ui/leaderboard_panel.gd`:

```gdscript
extends PanelContainer

signal close_requested

var _entries_container: VBoxContainer
var _player_row: HBoxContainer

func _ready():
	_build_ui()

func _build_ui():
	custom_minimum_size = Vector2(600, 500)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "LEADERBOARD"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Column headers
	var col_header = _make_row("RANK", "NAME", "SCORE", true)
	vbox.add_child(col_header)

	# Scrollable entries
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_entries_container = VBoxContainer.new()
	_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_entries_container)

	# Player's own rank (pinned at bottom)
	_player_row = _make_row("-", "-", "-", false)
	_player_row.visible = false
	vbox.add_child(_player_row)

func refresh():
	CloudManager.fetch_leaderboard()
	if not CloudManager.leaderboard_fetched.is_connected(_on_leaderboard_data):
		CloudManager.leaderboard_fetched.connect(_on_leaderboard_data)

func _on_leaderboard_data(data: Dictionary):
	# Clear old entries
	for child in _entries_container.get_children():
		child.queue_free()

	var entries = data.get("entries", [])
	for entry in entries:
		var rank = str(int(entry.get("rank", 0)))
		var name = str(entry.get("display_name", ""))
		var score = str(int(entry.get("score", 0)))
		var row = _make_row(rank, name, score, false)
		_entries_container.add_child(row)

	# Player's own rank
	var pr = data.get("player_rank")
	var ps = data.get("player_score")
	if pr != null and ps != null:
		_player_row.visible = true
		var labels = _player_row.get_children()
		labels[0].text = "#" + str(int(pr))
		labels[1].text = GameState.player_name if GameState.player_name != "" else "You"
		labels[2].text = str(int(ps))
	else:
		_player_row.visible = false

func _make_row(rank_text: String, name_text: String, score_text: String, is_header: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var rank_label = Label.new()
	rank_label.text = rank_text
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_header:
		rank_label.add_theme_font_size_override("font_size", 14)
		rank_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	row.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_header:
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	row.add_child(name_label)

	var score_label = Label.new()
	score_label.text = score_text
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_header:
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	row.add_child(score_label)

	return row
```

**Step 3: Wire leaderboard to desk scene**

Add a clickable trophy/award object to the desk, or add a leaderboard button to the HUD. The implementer should choose based on desk scene layout. Simplest approach: add to HUD as a small button, or add to the personal overlay system.

In `src/main.gd`, add to `_build_overlay_layer()`:

```gdscript
var leaderboard_panel = load("res://src/ui/leaderboard_panel.tscn").instantiate()
leaderboard_panel.visible = false
center.add_child(leaderboard_panel)
```

Add a variable and connect signals in `_connect_signals()`:

```gdscript
leaderboard_panel.close_requested.connect(_hide_overlay)
```

Add a way to open it (e.g., from HUD button or desk object).

**Step 4: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass.

**Step 5: Commit**

```bash
git add src/ui/leaderboard_panel.tscn src/ui/leaderboard_panel.gd src/main.gd
git commit -m "feat: add leaderboard panel UI"
```

---

### Task 11: Build Cloud/Profile Panel

**Files:**
- Create: `src/ui/cloud_panel.tscn` (minimal scene)
- Create: `src/ui/cloud_panel.gd`

**Step 1: Write cloud panel script**

`src/ui/cloud_panel.gd`:

```gdscript
extends PanelContainer

signal close_requested

var _name_edit: LineEdit
var _passphrase_label: Label
var _status_label: Label
var _leaderboard_toggle: CheckButton
var _username_edit: LineEdit
var _password_edit: LineEdit
var _register_btn: Button
var _login_section: VBoxContainer

func _ready():
	_build_ui()

func _build_ui():
	custom_minimum_size = Vector2(450, 500)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "CLOUD PROFILE"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Display name
	var name_section = VBoxContainer.new()
	vbox.add_child(name_section)
	var name_label = Label.new()
	name_label.text = "Display Name"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	name_section.add_child(name_label)

	var name_row = HBoxContainer.new()
	name_section.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "Enter your name..."
	name_row.add_child(_name_edit)
	var save_name_btn = Button.new()
	save_name_btn.text = "Save"
	save_name_btn.pressed.connect(_on_save_name)
	name_row.add_child(save_name_btn)

	# Passphrase
	var pass_section = VBoxContainer.new()
	vbox.add_child(pass_section)
	var pass_label = Label.new()
	pass_label.text = "Recovery Passphrase"
	pass_label.add_theme_font_size_override("font_size", 14)
	pass_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	pass_section.add_child(pass_label)
	_passphrase_label = Label.new()
	_passphrase_label.text = "Not connected"
	_passphrase_label.add_theme_font_size_override("font_size", 18)
	pass_section.add_child(_passphrase_label)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	vbox.add_child(_status_label)

	# Leaderboard toggle
	_leaderboard_toggle = CheckButton.new()
	_leaderboard_toggle.text = "Show on leaderboard"
	_leaderboard_toggle.button_pressed = true
	_leaderboard_toggle.toggled.connect(_on_leaderboard_toggled)
	vbox.add_child(_leaderboard_toggle)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Account upgrade section
	var account_label = Label.new()
	account_label.text = "Create Account (Optional)"
	account_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(account_label)

	_username_edit = LineEdit.new()
	_username_edit.placeholder_text = "Username"
	vbox.add_child(_username_edit)

	_password_edit = LineEdit.new()
	_password_edit.placeholder_text = "Password"
	_password_edit.secret = true
	vbox.add_child(_password_edit)

	_register_btn = Button.new()
	_register_btn.text = "Create Account"
	_register_btn.pressed.connect(_on_register)
	vbox.add_child(_register_btn)

func refresh():
	_name_edit.text = GameState.player_name
	if CloudManager.is_authenticated():
		_passphrase_label.text = CloudManager.passphrase
		_status_label.text = "Connected"
	else:
		_passphrase_label.text = "Not connected"
		_status_label.text = "Offline"

func _on_save_name():
	var new_name = _name_edit.text.strip_edges()
	if new_name == "":
		return
	GameState.player_name = new_name
	if CloudManager.is_authenticated():
		CloudManager.update_display_name(new_name)
	_status_label.text = "Name saved"

func _on_leaderboard_toggled(pressed: bool):
	CloudManager.set_leaderboard_visibility(pressed)

func _on_register():
	var username = _username_edit.text.strip_edges()
	var password = _password_edit.text
	if username == "" or password == "":
		_status_label.text = "Enter username and password"
		return
	var success = await CloudManager.register_account(username, password)
	if success:
		_status_label.text = "Account created!"
		_register_btn.text = "Account Created"
		_register_btn.disabled = true
	else:
		_status_label.text = "Username taken or error"
```

**Step 2: Wire to main.gd overlay system**

Same pattern as other panels — add to `_build_overlay_layer()` and `_connect_signals()`.

**Step 3: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass.

**Step 4: Commit**

```bash
git add src/ui/cloud_panel.tscn src/ui/cloud_panel.gd src/main.gd
git commit -m "feat: add cloud profile panel for name, passphrase, account"
```

---

### Task 12: Update Welcome Screen with Name Entry and Recovery

**Files:**
- Modify: `src/main.gd:243-317` (_build_welcome_layer)

**Step 1: Update welcome screen**

Add a name entry `LineEdit` before the "New Game" button. Add a "Recover Save" button after "Dev Save".

In `_build_welcome_layer()`:

```gdscript
# Before start_btn:
var name_edit = LineEdit.new()
name_edit.placeholder_text = "Enter your name..."
name_edit.custom_minimum_size = Vector2(250, 40)
name_edit.add_theme_font_size_override("font_size", 16)
name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
content.add_child(name_edit)
```

Update `_on_start_game` to accept the name and create cloud player:

```gdscript
func _on_start_game(load_save: bool = false, player_name: String = ""):
	# ... existing code ...
	if not load_save and player_name != "":
		GameState.player_name = player_name
		if not CloudManager.is_authenticated():
			CloudManager.create_player(player_name)
```

Add "Recover Save" button:

```gdscript
var recover_btn = Button.new()
recover_btn.text = "Recover Save"
recover_btn.custom_minimum_size = Vector2(200, 40)
recover_btn.add_theme_font_size_override("font_size", 14)
recover_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
recover_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
recover_btn.pressed.connect(_show_recover_dialog)
content.add_child(recover_btn)
```

Implement `_show_recover_dialog()` as a simple popup with a LineEdit for passphrase input and a "Recover" button.

**Step 2: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass.

**Step 3: Commit**

```bash
git add src/main.gd
git commit -m "feat: add name entry and save recovery to welcome screen"
```

---

### Task 13: Add Access Points for Leaderboard and Cloud Panels

**Files:**
- Modify: `src/ui/hud.gd` or `src/office/desk_scene.gd` (add buttons/clickable areas)
- Modify: `src/main.gd` (connect new access points)

**Step 1: Decide access method**

Add two small buttons to the HUD (top bar): a trophy icon/button for leaderboard, and a cloud icon/button for profile. Alternatively, add clickable objects to the desk scene.

The implementer should choose based on the existing HUD layout. The simplest approach is adding buttons to the HUD.

**Step 2: Wire buttons**

In `src/main.gd`, add handler methods:

```gdscript
func _on_leaderboard_pressed():
	if state != DeskState.DESK:
		return
	leaderboard_panel.refresh()
	_show_overlay(leaderboard_panel)

func _on_cloud_pressed():
	if state != DeskState.DESK:
		return
	cloud_panel.refresh()
	_show_overlay(cloud_panel)
```

**Step 3: Run tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass.

**Step 4: Manual testing**

Run the game and verify:
- Leaderboard opens from HUD button
- Cloud panel opens from HUD button
- Both close with X button and dimmer click

**Step 5: Commit**

```bash
git add src/ui/hud.gd src/main.gd
git commit -m "feat: add HUD buttons for leaderboard and cloud profile access"
```

---

### Task 14: Backend Deployment Setup

**Files:**
- Create: `backend/Dockerfile` (optional, if containerized)
- Create: `backend/systemd/consultancy-tycoon-api.service`

**Step 1: Create systemd service file**

```ini
[Unit]
Description=Consultancy Tycoon API
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/consultancy-tycoon-api
ExecStart=/opt/consultancy-tycoon-api/consultancy-tycoon-api
EnvironmentFile=/opt/consultancy-tycoon-api/.env
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Step 2: Build release binary**

```bash
cd backend && cargo build --release
```

**Step 3: Run migrations**

```bash
psql -U postgres -c "CREATE DATABASE consultancy_tycoon;"
psql -U postgres -d consultancy_tycoon -f backend/migrations/001_initial.sql
```

**Step 4: Deploy**

Copy binary + .env to server, enable and start the systemd service. Set up reverse proxy (nginx) to forward `/api/*` to `127.0.0.1:3080`.

**Step 5: Commit**

```bash
git add backend/systemd/ backend/Dockerfile
git commit -m "feat: add deployment config for backend service"
```

---

### Task 15: End-to-End Testing and Polish

**Step 1: Run all Godot tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass (186+).

**Step 2: Manual end-to-end test checklist**

- [ ] Start new game, enter name → player created on server
- [ ] Play for 60s → autosave syncs scores and save to cloud
- [ ] Open leaderboard → see your entry
- [ ] Open cloud panel → see passphrase, edit name
- [ ] Open cloud panel → create account with username/password
- [ ] Open new browser → recover with passphrase → save loads
- [ ] Open new browser → login with username/password → save loads
- [ ] Toggle leaderboard opt-out → confirm removal from board
- [ ] Kill server → game continues working (local saves unaffected)

**Step 3: Fix any issues found**

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete highscores and cloud saves integration"
```
