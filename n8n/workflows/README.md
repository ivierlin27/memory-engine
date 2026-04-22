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

### Planka → n8n (Settings → Webhooks)

These fields are unrelated to **`MEMORY_ENGINE_PLANKA_URL`** (that env is for **n8n calling Planka’s REST API** when creating cards).

| Field | Value |
|--------|--------|
| **Title** | Any label, e.g. `Memory Engine · card moved` |
| **URL** | **`https://n8n.<DOMAIN>/webhook/planka-card-moved`** (same **`DOMAIN`** as compose / NPM; production webhook path — workflow must be **published/active**) |
| **Access token** | Leave empty unless you add webhook auth on the n8n side (default workflow webhook has **authentication: none**) |
| **Events** | Prefer events that fire when a **card moves** between lists if Planka exposes them; otherwise **All** is OK but chatty |
| **Excluded events** | Optional; trim noise if needed |

Then: keep **ME · Planka card moved** active, ensure **`PLANKA_REJECTED_LIST_ID`** matches the UUID of your real “Rejected” column/list, and after the first real delivery open **Extract IDs** and align fields if **`destListId`** / **`cardId`** never match Planka’s JSON.

### End-to-end checks

From any machine that can reach n8n over HTTPS:

```bash
export N8N_BASE="https://n8n.<DOMAIN>"
export PLANKA_REJECTED_LIST_ID="<paste from Planka/settings or .env>"
./scripts/e2e-memory-engine.sh
```

Optional: **`RUN_DIGEST=1`** and **`N8N_SSH=user@lxc`** runs **`ME · Weekly digest`** once via **`n8n execute`** on the Docker host (needs LM Studio up). Omit or **`SKIP_DIGEST=1`** otherwise.

After pulling this repo, **re-import** **`ingest.json`** (or sync the workflow in the UI) so **`PG link Planka id`** exists — without it **`planka_card_id`** stays unset and the rejection branch cannot update **`inbox`**.

## What each workflow does (short)

- **Ingest** — POST JSON `{ "type", "content", "source" }` → Mem0 (`/memories`) → **`inbox` row** → **Planka Inbox card** → stores **`planka_card_id`** on **`inbox`** when the API returns **`item.id`** (needed for rejection sync).
- **Session end** — POST JSON with `source`, `raw_summary`, and optional arrays matching `sessions` columns → insert into `sessions`.
- **Planka card moved** — POST from Planka webhook; if destination list id equals **`PLANKA_REJECTED_LIST_ID`**, inserts `rejection_log` and sets `inbox.status = rejected` where `planka_card_id` matches. **Edit the Code node** `Extract IDs` after your first real payload so `destListId` / `cardId` match Planka’s JSON.
- **Weekly digest** — Sunday 20:00 (workflow timezone / server TZ) → summarize last 7 days of `sessions.raw_summary` via LM Studio → **ntfy**.

## Full node graphs

See **MEMORY_ENGINE_BUILD_PLAN_v2** §7 (advanced branches: SearXNG, yt-dlp, loops, etc.). These JSON files are a **baseline** you can extend.

## Export after edits

Use **Workflow → Download** or the API; commit updated JSON here.
