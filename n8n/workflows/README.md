# n8n workflow exports

After building workflows in the n8n UI (MEMORY_ENGINE_BUILD_PLAN_v2 §7):

1. **Settings → Export** each workflow, or use the API (see `scripts/backup.sh`).
2. Save JSON files here (e.g. `ingest.json`, `session-end.json`).
3. Commit to git.

### Webhook paths (reference)

| Workflow        | Path                      |
|-----------------|---------------------------|
| Inbox ingest    | `/webhook/ingest`         |
| Session end     | `/webhook/session-end`    |
| Planka moved    | `/webhook/planka-card-moved` |

### Node chains

See build plan §7.1–7.4 for full node graphs (SearXNG, Mem0, Postgres, Planka, ntfy, LM Studio chat for digest).
