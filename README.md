# memory-engine

Self-hosted AI memory stack (PostgreSQL + pgvector, Qdrant, Khoj, Mem0, n8n, Planka) for Proxmox LXC per **MEMORY_ENGINE_BUILD_PLAN_v2** (see `~/.cursor/plans/MEMORY_ENGINE_BUILD_PLAN_v2.md` on your Mac).

## Quick start

1. Fill [docs/PREREQS.md](docs/PREREQS.md) and copy [scripts/lxc.env.example](scripts/lxc.env.example) to `scripts/lxc.env` (gitignored).
2. On Proxmox host: run [scripts/provision-lxc-on-proxmox.sh](scripts/provision-lxc-on-proxmox.sh) (after editing `lxc.env`).
3. Copy `.env.example` → `.env`, set `LM_STUDIO_HOST` and secrets.
4. **Create `.env` on the LXC** in the same directory as `docker-compose.yml` (the file is gitignored, so rsync will not copy it). Either copy from Mac: `scp .env root@memory-engine.dev-path.org:/opt/memory-engine/.env` or `cp .env.example .env` on the server and fill values, then `chmod 600 .env`.
5. From this Mac: `./scripts/sync-to-lxc.sh root@memory-engine.dev-path.org`
6. On LXC: `cd /opt/memory-engine && docker compose build mem0 && docker compose up -d`  
   (Do not expect `memory-mem0-api:local` to exist on Docker Hub — it is **built** on the LXC. `docker compose pull` is safe for other services; Mem0 uses `pull_policy: never`.)

**Mem0 API:** Built from [mem0ai/mem0 `server/`](https://github.com/mem0ai/mem0/tree/main/server) via [docker/mem0-api-server/Dockerfile](docker/mem0-api-server/Dockerfile) because the published `mem0/mem0-api-server` image is **arm64-only** (no `linux/amd64` on Proxmox x86). First `docker compose up` will **build** the image (needs internet to `git clone` and `pip install`). API is **8000** in the container, **8080** on the host. n8n should call `http://mem0:8000`. The server defaults to OpenAI model IDs; for LM Studio use `OPENAI_BASE_URL` and/or `POST /configure` — see [Mem0 server](https://github.com/mem0ai/mem0/tree/main/server).

Full sequence: [docs/DEPLOY.md](docs/DEPLOY.md). Post-deploy UI steps: [docs/OPERATIONS.md](docs/OPERATIONS.md). If n8n/Planka or Khoj DB errors: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Image pins

| Service   | Image tag              |
|-----------|------------------------|
| Postgres  | `pgvector/pgvector:pg16` |
| Qdrant    | `qdrant/qdrant:v1.17.1` |
| n8n       | `n8nio/n8n:2.17.0`     |
| Mem0      | `memory-mem0-api:local` (built from `docker/mem0-api-server/`) |
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
