CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source          TEXT NOT NULL,
    raw_summary     TEXT,
    projects_touched TEXT[],
    new_concepts    TEXT[],
    decisions_made  TEXT[],
    open_questions  TEXT[]
);

CREATE TABLE IF NOT EXISTS inbox (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    item_type       TEXT NOT NULL,
    raw_input       TEXT NOT NULL,
    title           TEXT,
    summary         TEXT,
    related_projects TEXT[],
    recommendation  TEXT,
    status          TEXT NOT NULL DEFAULT 'pending',
    planka_card_id  TEXT,
    deferred_until  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS rejection_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rejected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    item            TEXT NOT NULL,
    reason          TEXT,
    reversible      BOOLEAN DEFAULT TRUE,
    reversed_at     TIMESTAMPTZ,
    source_inbox_id UUID REFERENCES inbox(id)
);

CREATE TABLE IF NOT EXISTS projects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    planka_card_id  TEXT UNIQUE,
    name            TEXT NOT NULL,
    status          TEXT NOT NULL,
    description     TEXT,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
