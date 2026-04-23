# n8n workflow exports

Workflow JSON files in this folder can be **imported** into n8n (**Workflows** menu → **Import from File…**).

| File | Webhook path (production) |
|------|---------------------------|
| `ingest.json` | `/webhook/ingest` |
| `session-end.json` | `/webhook/session-end` |
| `planka-card-moved.json` | `/webhook/planka-card-moved` |
| `planka-control-plane.json` | `/webhook/planka-control-plane` |
| `weekly-digest.json` | *(Schedule Trigger — no webhook)* |

## Hybrid maintenance scripts

The derived wiki compiler and contradiction scan are currently versioned as
repo scripts rather than imported workflows:

- `scripts/wiki_compile.py`
- `scripts/scan_contradictions.py`
- `scripts/run-hybrid-maintenance.sh`

This keeps the core logic in git and lets you trigger it from cron, systemd,
or n8n later without rebuilding the logic in the canvas.

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
   - optional control-plane list ids / webhooks:
     `PLANKA_PLAN_READY_LIST_ID`, `PLANKA_APPROVED_LIST_ID`,
     `PLANKA_AUTHOR_REVIEW_LIST_ID`, `PLANKA_NEEDS_HUMAN_LIST_ID`,
     `AUTHOR_AGENT_PLAN_WEBHOOK_URL`, `AUTHOR_AGENT_EXECUTE_WEBHOOK_URL`,
     `REVIEW_AGENT_WEBHOOK_URL`, `HUMAN_REVIEW_WEBHOOK_URL`
   - `LM_STUDIO_HOST`, `LM_STUDIO_PORT`, `LLM_MODEL` (weekly digest)
   - `NTFY_TOPIC` (optional; digest **ntfy** step fails softly if empty)
   - optional gateway / compiler vars: `MEMORY_ENGINE_LLM_BASE_URL`,
     `MEMORY_ENGINE_STRONG_MODEL`, `PLANKA_REVIEW_LIST_ID`

### Planka → n8n (Settings → Webhooks)

These fields are unrelated to **`MEMORY_ENGINE_PLANKA_URL`** (that env is for **n8n calling Planka’s REST API** when creating cards).

| Field | Value |
|--------|--------|
| **Title** | Any label, e.g. `Memory Engine · card moved` |
| **URL** | **`https://n8n.<DOMAIN>/webhook/planka-card-moved`** (same **`DOMAIN`** as compose / NPM; production webhook path — workflow must be **published/active**) |
| **Access token** | Leave empty unless you add webhook auth on the n8n side (default workflow webhook has **authentication: none**) |
| **Events** | Prefer **`cardUpdate`** only for this workflow — Planka has no `cardMoved`; moving a column/list usually updates the card (**`cardUpdate`**). Start there; if executions never fire on drag, broaden (e.g. **`All`** once, inspect payload, then narrow again). |
| **Excluded events** | Leave **`None`** if you selected only **`cardUpdate`**. If you instead choose **All**, use exclusions to drop noise unrelated to lane changes, e.g. **`attachment*`**, **`comment*`**, **`notification*`**, **`backgroundImage*`**, **`task*`**, **`label*`**, **`customField*`**, **`webhook*`**, **`user*`**, **`notificationService*`**. Tune after you see traffic. |

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
- **Planka control plane** — POST from a second Planka webhook; routes card moves to author/review/human webhooks based on destination list id and can send `ntfy` for human review.
- **Weekly digest** — Sunday 20:00 (workflow timezone / server TZ) → summarize last 7 days of `sessions.raw_summary` via LM Studio → **ntfy**.
- **Hybrid scripts** — `run-hybrid-maintenance.sh` compiles `obsidian_vault/compiled/` and writes contradiction findings/open tensions from the same structured sources.

## Full node graphs

See **MEMORY_ENGINE_BUILD_PLAN_v2** §7 (advanced branches: SearXNG, yt-dlp, loops, etc.). These JSON files are a **baseline** you can extend.

## Export after edits

Use **Workflow → Download** or the API; commit updated JSON here.

## Updating an existing workflow (avoid duplicated nodes)

**Import from File…** while editing the same workflow can **merge** JSON and duplicate nodes. Prefer **one** of:

1. **Replace on the server:** sync `n8n/workflows/*.json` to the LXC and apply canonical **`nodes`** / **`connections`** to **`workflow_entity`** + **`workflow_history`** for that workflow id (same approach as fixing a bad import), then restart n8n and **`n8n publish:workflow --id=…`**.
2. **Clean import:** duplicate/delete the broken workflow in the UI, then import the file as a **new** workflow (new id), then deactivate the old one and fix webhook URLs — more manual.
3. **Manual:** select stray nodes in the canvas and delete them, then save.

Requires **`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`** in **`docker-compose.yml`** so **`$env.*`** resolves in HTTP Request URLs and Code nodes (default n8n 2.x blocks env access in expressions).
