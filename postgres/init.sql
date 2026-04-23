CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source          TEXT NOT NULL,
    principal       TEXT NOT NULL DEFAULT 'human:unknown',
    raw_summary     TEXT,
    projects_touched TEXT[],
    new_concepts    TEXT[],
    decisions_made  TEXT[],
    open_questions  TEXT[],
    command_or_api  TEXT,
    git_ref         TEXT,
    artifact_url    TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS inbox (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    item_type       TEXT NOT NULL,
    raw_input       TEXT NOT NULL,
    principal       TEXT NOT NULL DEFAULT 'human:unknown',
    title           TEXT,
    summary         TEXT,
    related_projects TEXT[],
    recommendation  TEXT,
    status          TEXT NOT NULL DEFAULT 'pending',
    planka_card_id  TEXT,
    deferred_until  TIMESTAMPTZ,
    command_or_api  TEXT,
    git_ref         TEXT,
    artifact_url    TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb
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

CREATE TABLE IF NOT EXISTS compiled_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scope           TEXT NOT NULL,
    title           TEXT NOT NULL,
    relative_path   TEXT NOT NULL,
    principal       TEXT NOT NULL DEFAULT 'system:wiki-compiler',
    source_refs     JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS contradiction_findings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scope           TEXT NOT NULL,
    title           TEXT NOT NULL,
    summary         TEXT,
    severity        TEXT NOT NULL DEFAULT 'medium',
    status          TEXT NOT NULL DEFAULT 'open',
    principal       TEXT NOT NULL DEFAULT 'system:contradiction-scan',
    evidence        JSONB NOT NULL DEFAULT '[]'::jsonb,
    planka_card_id  TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb
);
