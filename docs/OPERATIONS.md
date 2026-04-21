# Operations after compose is up

Replace example IPs with your [PREREQS.md](PREREQS.md) values.

## Phase 3 — LM Studio (Alienware)

- LM Studio: bind `0.0.0.0`, port `1234`, CORS on. Second instance or embedding server on `1235`.
- Fedora: `sudo firewall-cmd --add-port=1234/tcp --permanent && sudo firewall-cmd --add-port=1235/tcp --permanent && sudo firewall-cmd --reload`
- From LXC: `curl -sS "http://<ALIENWARE>:1234/v1/models" | jq .`
- Pi-hole: `lmstudio.dev-path.org` → Alienware IP.

## Phase 4 — Nginx Proxy Manager

Websocket support ON, SSL Let’s Encrypt for each:

| Domain | Forward | Port |
|--------|---------|------|
| khoj.dev-path.org | LXC_IP | 42110 |
| n8n.dev-path.org | LXC_IP | 5678 |
| planka.dev-path.org | LXC_IP | 3000 |

Optional internal: `mcp.dev-path.org` → LXC_IP:8765 (Phase 8).

## Phase 5 — Khoj

Open `https://khoj.dev-path.org`.

- **Chat model**: OpenAI-compatible, base `http://<ALIENWARE>:1234/v1`, key `lm-studio`, model name exactly as in LM Studio.
- **Sync chat models from LM Studio**: On the LXC, from `/opt/memory-engine`, run `./scripts/sync-khoj-chat-models.sh` (or `docker compose exec -T khoj python3 /app/scripts/khoj_sync_lmstudio_chat_models.py`). This reads `GET /v1/models` using `OPENAI_BASE_URL` / `OPENAI_API_KEY` from compose and upserts Khoj **ChatModel** rows under an **Ai Model API** named `LM Studio (synced)`. Optional: `--dry-run`, `--prune` (remove Khoj models no longer listed). Requires the compose bind-mount on `scripts/khoj_sync_lmstudio_chat_models.py`.
- **Embeddings**: base `http://<ALIENWARE>:1235/v1`, model `nomic-embed-text`.
- **Search**: Custom URL `https://search.dev-path.org/search?q={query}&format=json`
- **Vault**: rsync Mac vault → LXC `/opt/memory-engine/obsidian_vault/`, in Khoj add `/app/vault`, Sync.
- **Agent**: “Project Memory” with Notes + Web search per build plan §5.4.

## Phase 6 — Planka

`https://planka.dev-path.org` — project **Personal Knowledge Work**, lists: Inbox, Backlog, In Progress, Review, Done, Rejected.

API token and list IDs:

```bash
curl -sS -X POST "https://planka.dev-path.org/api/access-tokens" \
  -H "Content-Type: application/json" \
  -d '{"emailOrUsername":"admin","password":"YOUR_ADMIN_PASSWORD"}'
```

Put token and Inbox/Rejected list IDs into `.env`, rsync, `docker compose up -d` if needed.

## Phase 7 — n8n

`https://n8n.dev-path.org` — build four workflows (ingest, session-end, planka-card-moved, weekly digest) per **MEMORY_ENGINE_BUILD_PLAN_v2** §7.1–7.4.

**Note:** `Execute Command` nodes (yt-dlp, pdftotext) require those binaries on the **n8n** host path. Easiest path: extend `n8nio/n8n` with a small Dockerfile on the LXC, or replace with HTTP-sidecar services later.

Test webhook:

```bash
curl -sS -X POST "https://n8n.dev-path.org/webhook/ingest" \
  -H "Content-Type: application/json" \
  -d '{"type":"url","content":"https://github.com/khoj-ai/khoj","source":"test"}'
```

Export workflows to `n8n/workflows/*.json` and commit.

## Phase 8 — MCP & Claude

### mem0-mcp (Mac, Claude Code)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
claude mcp add --scope user --transport stdio mem0 \
  --env MEM0_USER_ID=your-name \
  --env MEM0_PROVIDER=openai \
  --env OPENAI_API_KEY=lm-studio \
  --env OPENAI_BASE_URL="http://lmstudio.dev-path.org:1234/v1" \
  --env OPENAI_MODEL=qwen2.5-32b-instruct \
  --env QDRANT_HOST=memory-engine.dev-path.org \
  --env QDRANT_PORT=6333 \
  -- uvx --from git+https://github.com/elvismdev/mem0-mcp-selfhosted.git mem0-mcp-selfhosted
```

Ensure Mac can reach LXC:6333 if UFW allows LAN.

### Optional: claude.ai remote MCP

On LXC install `mcp-memory-service`, install unit from [mcp-memory.service](mcp-memory.service), proxy `mcp.dev-path.org` → `:8765`.

### CLAUDE.md

Copy [CLAUDE.md.template](CLAUDE.md.template) to `~/.claude/CLAUDE.md` on your Mac and edit placeholders.

## Phase 9 — iOS & Syncthing

- Shortcuts: POST `https://n8n.dev-path.org/webhook/ingest` with JSON body per build plan §9.1.
- PWAs: Add Khoj, Planka, n8n to Home Screen.
- Syncthing: `apt install syncthing` on LXC, pair with Mac for vault sync (§9.3).

## Phase 10 — Backup & UFW

On LXC:

```bash
chmod +x /opt/memory-engine/scripts/backup.sh /opt/memory-engine/scripts/ufw-lxc.sh
/opt/memory-engine/scripts/backup.sh   # test
echo "0 3 * * * /opt/memory-engine/scripts/backup.sh" | crontab -
LAN_CIDR=192.168.1.0/24 ./scripts/ufw-lxc.sh   # edit CIDR first
```

Verification checklist: build plan §10.4.
