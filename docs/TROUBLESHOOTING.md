# Troubleshooting

## Separate Postgres databases

n8n and Planka must **not** use the same database as each other (both define a `project` table and migrations conflict). This stack uses:

| Database | Apps |
|----------|------|
| `memory` | Custom `init.sql` tables, Khoj, Mem0 API |
| `n8n` | n8n only |
| `planka` | Planka only |

Fresh installs: `postgres/00-create-databases.sh` creates `n8n` and `planka` on first Postgres init.

## Existing Postgres volume (upgrade from single shared DB)

If Postgres was already initialized **without** those databases, create them manually:

```bash
docker compose exec postgres psql -U memory -d postgres -c "CREATE DATABASE n8n;"
docker compose exec postgres psql -U memory -d postgres -c "CREATE DATABASE planka;"
```

If `database already exists`, that step is done.

Then reset app state that targeted the wrong DB:

```bash
docker compose stop n8n planka
docker volume rm "$(basename "$(pwd)")_n8n_data"   # adjust compose project name if needed
docker compose up -d n8n planka
```

Use `docker volume ls | grep n8n` to get the exact volume name. Removing `n8n_data` clears broken migrations only for n8n.

## Khoj connects to localhost for Postgres

Khoj expects **`POSTGRES_HOST`** / **`POSTGRES_DB`** etc., not only `DATABASE_URL`. See current `docker-compose.yml` `khoj` service.

## Khoj Django admin returns **400** at `/server/admin`

Django returns **400 Bad Request** when the **`Host`** header is not in **`ALLOWED_HOSTS`** (`DisallowedHost`). Khoj builds that list from **`KHOJ_ALLOWED_DOMAIN`** (defaulting to **`KHOJ_DOMAIN`**, which defaults to **`khoj.dev`** if unset).

**Fix:** Set **`DOMAIN`** in `.env` (apex only, e.g. `dev-path.org`). This stack passes **`KHOJ_DOMAIN`** / **`KHOJ_ALLOWED_DOMAIN`** from `DOMAIN` in `docker-compose.yml`, so **`https://khoj.${DOMAIN}/server/admin/`** works.

**Raw IP (`http://192.168.x.x:42110`):** `Host` is the IP, which does not match `*.dev-path.org`. Either browse admin via **`https://khoj.<your-domain>`**, or temporarily set **`KHOJ_ALLOWED_DOMAIN`** to that IP in compose (Khoj allows one primary value here), then `docker compose up -d khoj`.

Use a **trailing slash**: `/server/admin/` (either usually redirects, but be consistent).

## Khoj / sync script: `Name or service not known` or URL contains `LXC_IP=`

`OPENAI_BASE_URL` is built from **`LM_STUDIO_HOST`** in `.env`. If you set `LM_STUDIO_HOST=LXC_IP=192.168.1.45` (copy-paste from docs), the URL becomes invalid. Use **only** the address:

```bash
LM_STUDIO_HOST=192.168.1.45
```

Then `docker compose up -d khoj` and re-run `./scripts/sync-khoj-chat-models.sh`.

## Mem0 ImportError psycopg

Rebuild the Mem0 image after Dockerfile changes:

```bash
docker compose build --no-cache mem0
docker compose up -d mem0
```
