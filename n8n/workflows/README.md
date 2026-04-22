# n8n workflow exports

Workflow JSON files in this folder can be **imported** into n8n (**Workflows** menu → **Import from File…**).

| File | Webhook path (production) |
|------|---------------------------|
| `ingest.json` | `/webhook/ingest` |
| `session-end.json` | `/webhook/session-end` |
| `planka-card-moved.json` | `/webhook/planka-card-moved` |
| `weekly-digest.json` | *(Schedule Trigger — no webhook)* |

## Prerequisites

1. **`docker-compose.yml`** passes **Planka**, **Mem0**, **LM Studio**, and **`NTFY_TOPIC`**-related variables into the **n8n** container (`MEMORY_ENGINE_*`, etc.). Reload after editing `.env`:

   `docker compose up -d n8n`

2. **Postgres credential in n8n** (one credential used by all workflows):
   - Host: `postgres`
   - Database: **`memory`** (not `n8n`)
   - User / password: same as `${POSTGRES_PASSWORD}` in `.env`
   - Exported workflows reference credential id **`a1c0feed-0001-4000-8000-00000000c001`** and name **`Memory Postgres`**. On a fresh n8n, create/import that credential first (same id) so nodes resolve.

3. **CLI import (optional):** from the repo root on the LXC, with the stack running: `bash scripts/n8n-memory-postgres-credential.sh` reads `.env` and runs `n8n import:credentials`. If you use a different id, set `CRED_ID` or re-export workflows from the UI after changing the Postgres nodes.

4. **`.env`** must include at least:
   - `PLANKA_API_TOKEN`, `PLANKA_INBOX_LIST_ID`, `PLANKA_REJECTED_LIST_ID`
   - `LM_STUDIO_HOST`, `LM_STUDIO_PORT`, `LLM_MODEL` (weekly digest)
   - `NTFY_TOPIC` (optional; digest **ntfy** step fails softly if empty)

## What each workflow does (short)

- **Ingest** — POST JSON `{ "type", "content", "source" }` → Mem0 (`/memories`) → `inbox` row → Planka Inbox card.
- **Session end** — POST JSON with `source`, `raw_summary`, and optional arrays matching `sessions` columns → insert into `sessions`.
- **Planka card moved** — POST from Planka webhook; if destination list id equals **`PLANKA_REJECTED_LIST_ID`**, inserts `rejection_log` and sets `inbox.status = rejected` where `planka_card_id` matches. **Edit the Code node** `Extract IDs` after your first real payload so `destListId` / `cardId` match Planka’s JSON.
- **Weekly digest** — Sunday 20:00 (workflow timezone / server TZ) → summarize last 7 days of `sessions.raw_summary` via LM Studio → **ntfy**.

## Full node graphs

See **MEMORY_ENGINE_BUILD_PLAN_v2** §7 (advanced branches: SearXNG, yt-dlp, loops, etc.). These JSON files are a **baseline** you can extend.

## Export after edits

Use **Workflow → Download** or the API; commit updated JSON here.
