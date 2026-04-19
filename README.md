# memory-engine

Self-hosted AI memory stack (PostgreSQL + pgvector, Qdrant, Khoj, Mem0, n8n, Planka) for Proxmox LXC per **MEMORY_ENGINE_BUILD_PLAN_v2** (see `~/.cursor/plans/MEMORY_ENGINE_BUILD_PLAN_v2.md` on your Mac).

## Quick start

1. Fill [docs/PREREQS.md](docs/PREREQS.md) and copy [scripts/lxc.env.example](scripts/lxc.env.example) to `scripts/lxc.env` (gitignored).
2. On Proxmox host: run [scripts/provision-lxc-on-proxmox.sh](scripts/provision-lxc-on-proxmox.sh) (after editing `lxc.env`).
3. Copy `.env.example` → `.env`, set `LM_STUDIO_HOST` and secrets.
4. **Create `.env` on the LXC** in the same directory as `docker-compose.yml` (the file is gitignored, so rsync will not copy it). Either copy from Mac: `scp .env root@memory-engine.dev-path.org:/opt/memory-engine/.env` or `cp .env.example .env` on the server and fill values, then `chmod 600 .env`.
5. From this Mac: `./scripts/sync-to-lxc.sh root@memory-engine.dev-path.org`
6. On LXC: `cd /opt/memory-engine && docker compose up -d`

**Mem0 image:** `mem0/mem0-api-server` (official). API inside Docker is port **8000**; host **8080**. n8n on the same compose network should call `http://mem0:8000`, not `:8080`. The bundled server defaults to OpenAI model IDs; LM Studio may need matching loaded models or `POST /configure` with a custom Mem0 config — see [Mem0 server](https://github.com/mem0ai/mem0/tree/main/server).

Full sequence: [docs/DEPLOY.md](docs/DEPLOY.md). Post-deploy UI steps: [docs/OPERATIONS.md](docs/OPERATIONS.md).

## Image pins

| Service   | Image tag              |
|-----------|------------------------|
| Postgres  | `pgvector/pgvector:pg16` |
| Qdrant    | `qdrant/qdrant:v1.17.1` |
| n8n       | `n8nio/n8n:2.17.0`     |
| Mem0      | `mem0/mem0-api-server:latest` (pin digest after first pull) |
| Khoj/Planka | `latest` (pin to digest after first `docker compose pull`) |

## Git (personal GitHub)

Repo is already initialized on disk. Set your **personal** identity for this repo only, then fix the last commit author if needed:

```bash
cd ~/projects/memory-engine
./scripts/init-git-personal.sh
git commit --amend --reset-author --no-edit
# Add remote (personal SSH host alias), then push
```

Never commit `.env`. Use `.env.example` only for key names.

## n8n workflows

Build in UI per [docs/OPERATIONS.md](docs/OPERATIONS.md) §Phase 7. Export JSON into `n8n/workflows/` and commit.
