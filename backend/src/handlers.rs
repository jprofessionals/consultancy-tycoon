use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use rand::Rng;
use uuid::Uuid;

use crate::{
    auth::{create_token, AuthPlayer, OptionalAuthPlayer},
    db,
    models::*,
    AppState,
};

const ADJECTIVES: &[&str] = &[
    "BRAVE", "CALM", "DARK", "FAST", "GOLD", "HAPPY", "ICY", "KEEN", "LOUD", "MILD",
    "NEAT", "ODD", "PINK", "QUICK", "RED", "SAFE", "TALL", "VAST", "WARM", "ZESTY",
];

const NOUNS: &[&str] = &[
    "BEAR", "CAT", "DEER", "ELK", "FOX", "GOAT", "HAWK", "IBIS", "JAY", "KITE",
    "LION", "MOON", "NEWT", "OWL", "PIKE", "QUAIL", "ROSE", "STAR", "TOAD", "WOLF",
];

fn generate_passphrase() -> String {
    let mut rng = rand::rng();
    let adj = ADJECTIVES[rng.random_range(0..ADJECTIVES.len())];
    let noun = NOUNS[rng.random_range(0..NOUNS.len())];
    let num: u32 = rng.random_range(10..100);
    format!("{adj}-{noun}-{num}")
}

/// POST /api/players — Create a new anonymous player.
pub async fn create_player(
    State(state): State<AppState>,
    Json(req): Json<CreatePlayerRequest>,
) -> Result<impl IntoResponse, StatusCode> {
    let id = Uuid::new_v4();
    let passphrase = generate_passphrase();

    db::create_player(&state.db, id, &req.display_name, &passphrase)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let token =
        create_token(id, &state.jwt_secret).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(CreatePlayerResponse {
        id,
        passphrase,
        token,
    }))
}

/// POST /api/players/recover — Recover account by passphrase.
pub async fn recover_player(
    State(state): State<AppState>,
    Json(req): Json<RecoverRequest>,
) -> Result<impl IntoResponse, StatusCode> {
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

/// POST /api/players/register — Upgrade anonymous account with username/password. Requires auth.
pub async fn register(
    AuthPlayer(player_id): AuthPlayer,
    State(state): State<AppState>,
    Json(req): Json<RegisterRequest>,
) -> Result<impl IntoResponse, StatusCode> {
    // Check if username is already taken
    let existing = db::find_player_by_username(&state.db, &req.username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    if existing.is_some() {
        return Err(StatusCode::CONFLICT);
    }

    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(req.password.as_bytes(), &salt)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .to_string();

    db::set_credentials(&state.db, player_id, &req.username, &password_hash)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// POST /api/players/login — Login with username/password.
pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<impl IntoResponse, StatusCode> {
    let player = db::find_player_by_username(&state.db, &req.username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let stored_hash = player.password_hash.ok_or(StatusCode::UNAUTHORIZED)?;
    let parsed_hash =
        PasswordHash::new(&stored_hash).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Argon2::default()
        .verify_password(req.password.as_bytes(), &parsed_hash)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    let token = create_token(player.id, &state.jwt_secret)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(AuthResponse {
        id: player.id,
        display_name: player.display_name,
        token,
    }))
}

/// PATCH /api/players/me — Update display_name and/or show_on_leaderboard.
pub async fn update_player(
    AuthPlayer(player_id): AuthPlayer,
    State(state): State<AppState>,
    Json(req): Json<UpdatePlayerRequest>,
) -> Result<impl IntoResponse, StatusCode> {
    db::update_player(
        &state.db,
        player_id,
        req.display_name.as_deref(),
        req.show_on_leaderboard,
    )
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// PUT /api/scores — Submit score components.
pub async fn submit_scores(
    AuthPlayer(player_id): AuthPlayer,
    State(state): State<AppState>,
    Json(scores): Json<ScoreSubmission>,
) -> Result<impl IntoResponse, StatusCode> {
    db::upsert_scores(&state.db, player_id, &scores)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// GET /api/leaderboard — Get top 50 + optional player rank.
pub async fn get_leaderboard(
    auth: OptionalAuthPlayer,
    State(state): State<AppState>,
) -> Result<impl IntoResponse, StatusCode> {
    let entries = db::get_leaderboard(&state.db, 50)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (player_rank, player_score) = if let Some(player_id) = auth.0 {
        match db::get_player_rank(&state.db, player_id).await {
            Ok(Some((rank, score))) => (Some(rank), Some(score)),
            Ok(None) => (None, None),
            Err(_) => (None, None),
        }
    } else {
        (None, None)
    };

    Ok(Json(LeaderboardResponse {
        entries,
        player_rank,
        player_score,
    }))
}

/// PUT /api/saves — Upload cloud save.
pub async fn upload_save(
    AuthPlayer(player_id): AuthPlayer,
    State(state): State<AppState>,
    Json(save): Json<SaveUpload>,
) -> Result<impl IntoResponse, StatusCode> {
    db::upsert_save(&state.db, player_id, &save.save_data, save.version)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::OK)
}

/// GET /api/saves/me — Download cloud save.
pub async fn download_save(
    AuthPlayer(player_id): AuthPlayer,
    State(state): State<AppState>,
) -> Result<impl IntoResponse, StatusCode> {
    let save = db::get_save(&state.db, player_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(save))
}
