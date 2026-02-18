use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,
    pub exp: usize,
}

pub fn create_token(player_id: Uuid, secret: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let expiry = chrono::Utc::now()
        .checked_add_signed(chrono::TimeDelta::days(365))
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

/// Extractor that validates Bearer token and returns player UUID.
pub struct AuthPlayer(pub Uuid);

impl FromRequestParts<AppState> for AuthPlayer {
    type Rejection = StatusCode;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or(StatusCode::UNAUTHORIZED)?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or(StatusCode::UNAUTHORIZED)?;

        let claims =
            verify_token(token, &state.jwt_secret).map_err(|_| StatusCode::UNAUTHORIZED)?;

        Ok(AuthPlayer(claims.sub))
    }
}

/// Optional auth extractor — returns None if no auth header present.
pub struct OptionalAuthPlayer(pub Option<Uuid>);

impl FromRequestParts<AppState> for OptionalAuthPlayer {
    type Rejection = StatusCode;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok());

        let Some(auth_header) = auth_header else {
            return Ok(OptionalAuthPlayer(None));
        };

        let Some(token) = auth_header.strip_prefix("Bearer ") else {
            return Ok(OptionalAuthPlayer(None));
        };

        match verify_token(token, &state.jwt_secret) {
            Ok(claims) => Ok(OptionalAuthPlayer(Some(claims.sub))),
            Err(_) => Ok(OptionalAuthPlayer(None)),
        }
    }
}
