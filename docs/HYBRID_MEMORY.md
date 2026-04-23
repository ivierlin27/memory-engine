# Hybrid Memory Conventions

This repo treats the memory stack as a **DB-first Open Brain** with a
**generated wiki layer** on top.

## Source of truth

1. **Structured memory**  
   Mem0, Postgres, and Qdrant hold the durable memory layer used by agents.
2. **Authoritative project state**  
   Git-backed config, docs, inventories, and exports define what is deployed.
3. **Compiled wiki**  
   Markdown under `obsidian_vault/compiled/` is **derived output** for humans.

If a compiled page is wrong, fix the upstream source and regenerate it. Do not
hand-edit compiled pages as if they were authoritative documents.

## Generated-only rule

- `obsidian_vault/compiled/current/` is regenerated output.
- `obsidian_vault/compiled/history/` may contain timestamped snapshots.
- Any human scratch notes must live outside `compiled/`, for example under a
  separate `human_scratch/` subtree that retrieval can exclude by default.

## Provenance contract

Automation that writes to the database or to compiled markdown should carry:

- `principal` — who produced the event, e.g. `agent:homelab`
- `source` — `operator`, `agent`, or `human`
- `host`
- `command_or_api`
- `git_ref` when a repo change or declared config is involved
- `artifact_url` when there is a Planka card, MR, or other review artifact

Compiled pages should begin with YAML frontmatter:

```yaml
---
derived: true
generated_at: 2026-04-23T00:00:00Z
sources:
  - type: session
    id: ...
  - type: git
    ref: homelab@abc1234
scope: weekly
principal: system:wiki-compiler
---
```

## Retrieval policy

- Treat `compiled/` as **secondary retrieval input**.
- Favor raw vault notes, git-backed docs, and structured records when answering
  operational questions.
- Use compiled pages for browsing, summaries, and briefings.

## Compiler inputs

The compiler is allowed to use:

- recent `sessions`
- recent `inbox` items
- relevant Planka card metadata
- git summaries or explicit git exports
- optional metrics summaries

The compiler should not invent source references. If a source cannot be cited,
the claim should be dropped or written as an open question.

## Contradiction handling

Contradictions are useful. The system should preserve them rather than
flattening them into one smooth story.

The contradiction scanner can:

- write `open-tensions.md` in `compiled/current/`
- create a Planka card when configured
- leave evidence references in frontmatter or a JSON sidecar

## Current implementation artifacts

- Compiler script: `scripts/wiki_compile.py`
- Contradiction scan script: `scripts/scan_contradictions.py`
- Migration helper: `scripts/apply-sql-migrations.sh`
- SQL migration: `postgres/migrations/20260423_hybrid_memory.sql`
