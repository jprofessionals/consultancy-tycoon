use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{LeaderboardEntry, Player, SaveDownload, ScoreSubmission};

/// Insert a new player and an empty score_components row in a transaction.
pub async fn create_player(
    pool: &PgPool,
    id: Uuid,
    display_name: &str,
    passphrase: &str,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query(
        r#"
        INSERT INTO players (id, display_name, passphrase)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(id)
    .bind(display_name)
    .bind(passphrase)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"
        INSERT INTO score_components (player_id)
        VALUES ($1)
        "#,
    )
    .bind(id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

/// Find a player by their recovery passphrase.
pub async fn find_player_by_passphrase(
    pool: &PgPool,
    passphrase: &str,
) -> Result<Option<Player>, sqlx::Error> {
    sqlx::query_as::<_, Player>(
        r#"
        SELECT id, display_name, passphrase, username, password_hash,
               show_on_leaderboard, created_at, updated_at
        FROM players
        WHERE passphrase = $1
        "#,
    )
    .bind(passphrase)
    .fetch_optional(pool)
    .await
}

/// Find a player by their username (for login).
pub async fn find_player_by_username(
    pool: &PgPool,
    username: &str,
) -> Result<Option<Player>, sqlx::Error> {
    sqlx::query_as::<_, Player>(
        r#"
        SELECT id, display_name, passphrase, username, password_hash,
               show_on_leaderboard, created_at, updated_at
        FROM players
        WHERE username = $1
        "#,
    )
    .bind(username)
    .fetch_optional(pool)
    .await
}

/// Update a player's display_name and/or show_on_leaderboard.
pub async fn update_player(
    pool: &PgPool,
    player_id: Uuid,
    display_name: Option<&str>,
    show_on_leaderboard: Option<bool>,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        UPDATE players
        SET display_name = COALESCE($2, display_name),
            show_on_leaderboard = COALESCE($3, show_on_leaderboard),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(player_id)
    .bind(display_name)
    .bind(show_on_leaderboard)
    .execute(pool)
    .await?;

    Ok(())
}

/// Set username and password_hash for account upgrade.
pub async fn set_credentials(
    pool: &PgPool,
    player_id: Uuid,
    username: &str,
    password_hash: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        UPDATE players
        SET username = $2,
            password_hash = $3,
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(player_id)
    .bind(username)
    .bind(password_hash)
    .execute(pool)
    .await?;

    Ok(())
}

/// Insert or update score components, using GREATEST to prevent score regression.
pub async fn upsert_scores(
    pool: &PgPool,
    player_id: Uuid,
    scores: &ScoreSubmission,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO score_components (
            player_id, total_money_earned, reputation, skill_levels_sum,
            consultants_count, ai_tool_tiers_sum, manual_tasks_completed
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (player_id) DO UPDATE SET
            total_money_earned = GREATEST(score_components.total_money_earned, EXCLUDED.total_money_earned),
            reputation = GREATEST(score_components.reputation, EXCLUDED.reputation),
            skill_levels_sum = GREATEST(score_components.skill_levels_sum, EXCLUDED.skill_levels_sum),
            consultants_count = GREATEST(score_components.consultants_count, EXCLUDED.consultants_count),
            ai_tool_tiers_sum = GREATEST(score_components.ai_tool_tiers_sum, EXCLUDED.ai_tool_tiers_sum),
            manual_tasks_completed = GREATEST(score_components.manual_tasks_completed, EXCLUDED.manual_tasks_completed),
            updated_at = NOW()
        "#,
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

const SCORE_FORMULA: &str = r#"
    (sc.total_money_earned * 1.0
     + sc.reputation * 500.0
     + sc.skill_levels_sum * 100
     + sc.consultants_count * 250
     + sc.ai_tool_tiers_sum * 150
     + sc.manual_tasks_completed * 50)
"#;

/// Get the top N leaderboard entries with computed score and rank.
pub async fn get_leaderboard(
    pool: &PgPool,
    limit: i64,
) -> Result<Vec<LeaderboardEntry>, sqlx::Error> {
    let query = format!(
        r#"
        SELECT
            ROW_NUMBER() OVER (ORDER BY {score} DESC) AS rank,
            p.display_name,
            {score} AS score,
            sc.total_money_earned,
            sc.reputation,
            sc.skill_levels_sum,
            sc.consultants_count,
            sc.ai_tool_tiers_sum,
            sc.manual_tasks_completed
        FROM score_components sc
        JOIN players p ON p.id = sc.player_id
        WHERE p.show_on_leaderboard = true
        ORDER BY score DESC
        LIMIT $1
        "#,
        score = SCORE_FORMULA
    );

    sqlx::query_as::<_, LeaderboardEntry>(&query)
        .bind(limit)
        .fetch_all(pool)
        .await
}

/// Get a single player's rank and score.
pub async fn get_player_rank(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Option<(i64, f64)>, sqlx::Error> {
    let query = format!(
        r#"
        WITH ranked AS (
            SELECT
                sc.player_id,
                ROW_NUMBER() OVER (ORDER BY {score} DESC) AS rank,
                {score} AS score
            FROM score_components sc
            JOIN players p ON p.id = sc.player_id
            WHERE p.show_on_leaderboard = true
        )
        SELECT rank, score
        FROM ranked
        WHERE player_id = $1
        "#,
        score = SCORE_FORMULA
    );

    let row: Option<(i64, f64)> = sqlx::query_as(&query)
        .bind(player_id)
        .fetch_optional(pool)
        .await?;

    Ok(row)
}

/// Upsert a cloud save.
pub async fn upsert_save(
    pool: &PgPool,
    player_id: Uuid,
    save_data: &serde_json::Value,
    version: i32,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO cloud_saves (player_id, save_data, version)
        VALUES ($1, $2, $3)
        ON CONFLICT (player_id) DO UPDATE SET
            save_data = EXCLUDED.save_data,
            version = EXCLUDED.version,
            updated_at = NOW()
        "#,
    )
    .bind(player_id)
    .bind(save_data)
    .bind(version)
    .execute(pool)
    .await?;

    Ok(())
}

/// Download a player's cloud save.
pub async fn get_save(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Option<SaveDownload>, sqlx::Error> {
    sqlx::query_as::<_, SaveDownload>(
        r#"
        SELECT save_data, version, updated_at
        FROM cloud_saves
        WHERE player_id = $1
        "#,
    )
    .bind(player_id)
    .fetch_optional(pool)
    .await
}
