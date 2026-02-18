# Highscores, Cloud Saves & Leaderboard Design

## Overview

Add a composite scoring system, online leaderboard, cloud save synchronization, and player identity to Consultancy Tycoon. The backend runs on the same VM as the game (tycoon.jpro.dev) using Rust + PostgreSQL.

## Composite Score

Score is calculated server-side from stored raw components. Weights can be adjusted without client changes.

**Formula (v1):**

```
score = (total_money_earned * 1.0)
      + (reputation * 500)
      + (skill_levels_sum * 100)
      + (consultants_count * 250)
      + (ai_tool_tiers_sum * 150)
      + (manual_tasks_completed * 50)
```

**Components:**
- `total_money_earned` — Lifetime earnings (spending doesn't reduce it)
- `reputation` — Cumulative reputation
- `skill_levels_sum` — Sum of all skill levels
- `consultants_count` — Current team size
- `ai_tool_tiers_sum` — Sum of all AI tool tiers
- `manual_tasks_completed` — Tasks completed by the player (not AI)

All components are stored individually in the database so the formula can be rebalanced at any time.

## Player Identity

Two-tier system with zero-friction onboarding and optional account upgrade.

### Tier 1: Anonymous with Passphrase

- On first play, client requests a new player from the server
- Server generates a UUID + memorable passphrase (e.g., `TIGER-MOON-42`)
- Player sets a display name (editable anytime)
- To restore on another device: enter passphrase to recover player ID and pull saves/scores

### Tier 2: Optional Account Upgrade

- Player can add a username + password to their existing player ID
- Password hashed with argon2 server-side
- Login with username + password from any device
- Passphrase still works as a recovery method

## Backend: Rust + Axum + PostgreSQL

### Database Schema

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
```

### API Endpoints

```
POST   /api/players              — Create player (returns UUID + passphrase + token)
POST   /api/players/recover      — Recover player by passphrase (returns token)
POST   /api/players/register     — Add username+password to existing player
POST   /api/players/login        — Login with username+password (returns token)
PATCH  /api/players/:id          — Update display name, leaderboard opt-out

PUT    /api/scores/:player_id    — Submit score components
GET    /api/leaderboard          — Top 50 + requesting player's rank

PUT    /api/saves/:player_id     — Upload save data
GET    /api/saves/:player_id     — Download save data
```

### Authentication

- Bearer token (JWT or opaque) returned on player creation/login/recovery
- Long-lived tokens (idle game, not high-security)
- Token sent with every authenticated request

### Anti-Cheat (Lightweight)

- Reject score submissions where component values decreased
- Rate-limit submissions to once per 30 seconds
- Cap maximum delta per submission (flag outliers, don't block)
- No client-side obfuscation — keep it simple for an idle game

## Godot Client Integration

### New Autoload: CloudManager

`src/autoload/cloud_manager.gd` — handles all server communication.

- Stores `player_id` and `auth_token` locally in `user://cloud_auth.json`
- Uses Godot `HTTPRequest` nodes for async HTTP calls
- Methods: `create_player()`, `recover_player()`, `register_account()`, `login()`, `sync_save()`, `submit_scores()`, `fetch_leaderboard()`, `update_profile()`

### GameState Changes

New fields:
- `total_money_earned: float` — incremented in `add_money()` for positive amounts only
- `total_manual_tasks_completed: int` — incremented on player-driven task completion (not AI)
- `player_name: String` — display name, editable

Both fields serialized in the save data (backward-compatible with old saves via defaults).

### Sync Flow

- Piggyback on existing 60s auto-save timer: save locally, then upload save + score components to server
- Best-effort sync — if server is unreachable, local saves still work, retry next cycle
- On game start with existing cloud auth: compare local and cloud save timestamps, offer to pull cloud save if newer

### Welcome Screen Changes

- "New Game" prompts for display name, creates cloud player in background
- "Continue" loads local save, syncs with cloud after load
- New "Recover Save" button — enter passphrase to pull cloud save and resume

### New UI Panels

**Leaderboard Panel:**
- Accessible from a new desk object (trophy/award on the wall) or HUD button
- Table: Rank, Name, Score
- Top 50 entries
- Current player's row highlighted and pinned at bottom if outside top 50
- Expandable rows showing score breakdown by component

**Cloud/Profile Panel:**
- Accessible from settings or profile icon
- Display name (editable text field)
- Passphrase display (copy button)
- Sync status indicator
- "Show on leaderboard" toggle (default: on)
- "Create Account" section: username + password fields for Tier 2 upgrade
- "Login" section: for existing accounts on new devices

## Privacy

- Leaderboard opt-out toggle in Cloud/Profile panel
- When opted out: scores still sync (personal tracking) but excluded from public leaderboard
- Player can still see their own calculated rank
- Default is opted in
