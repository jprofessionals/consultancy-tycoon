use axum::{
    routing::{get, patch, post, put},
    Router,
};
use sqlx::postgres::PgPoolOptions;
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;

mod auth;
mod db;
mod handlers;
mod models;

#[derive(Clone)]
pub struct AppState {
    pub db: sqlx::PgPool,
    pub jwt_secret: String,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let jwt_secret = std::env::var("JWT_SECRET").expect("JWT_SECRET must be set");
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
        .route("/api/players", post(handlers::create_player))
        .route("/api/players/recover", post(handlers::recover_player))
        .route("/api/players/register", post(handlers::register))
        .route("/api/players/login", post(handlers::login))
        .route("/api/players/me", patch(handlers::update_player))
        .route("/api/scores", put(handlers::submit_scores))
        .route("/api/leaderboard", get(handlers::get_leaderboard))
        .route("/api/saves", put(handlers::upload_save))
        .route("/api/saves/me", get(handlers::download_save))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(listen_addr).await.unwrap();
    println!("Listening on {listen_addr}");
    axum::serve(listener, app).await.unwrap();
}
