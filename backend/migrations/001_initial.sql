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
