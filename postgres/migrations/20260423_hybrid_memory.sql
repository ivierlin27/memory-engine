ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS principal TEXT NOT NULL DEFAULT 'human:unknown',
  ADD COLUMN IF NOT EXISTS command_or_api TEXT,
  ADD COLUMN IF NOT EXISTS git_ref TEXT,
  ADD COLUMN IF NOT EXISTS artifact_url TEXT,
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE inbox
  ADD COLUMN IF NOT EXISTS principal TEXT NOT NULL DEFAULT 'human:unknown',
  ADD COLUMN IF NOT EXISTS command_or_api TEXT,
  ADD COLUMN IF NOT EXISTS git_ref TEXT,
  ADD COLUMN IF NOT EXISTS artifact_url TEXT,
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

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
