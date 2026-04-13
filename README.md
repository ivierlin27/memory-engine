# memory-engine

Self-hosted AI memory stack (PostgreSQL + pgvector, Qdrant, Khoj, Mem0, n8n, Planka) for Proxmox LXC per **MEMORY_ENGINE_BUILD_PLAN_v2** (see `~/.cursor/plans/MEMORY_ENGINE_BUILD_PLAN_v2.md` on your Mac).

## Quick start

1. Fill [docs/PREREQS.md](docs/PREREQS.md) and copy [scripts/lxc.env.example](scripts/lxc.env.example) to `scripts/lxc.env` (gitignored).
2. On Proxmox host: run [scripts/provision-lxc-on-proxmox.sh](scripts/provision-lxc-on-proxmox.sh) (after editing `lxc.env`).
3. Copy `.env.example` → `.env`, set `LM_STUDIO_HOST` and secrets.
4. From this Mac: `./scripts/sync-to-lxc.sh root@memory-engine.dev-path.org`
5. On LXC: `cd /opt/memory-engine && docker compose up -d`

Full sequence: [docs/DEPLOY.md](docs/DEPLOY.md). Post-deploy UI steps: [docs/OPERATIONS.md](docs/OPERATIONS.md).

## Image pins

| Service   | Image tag              |
|-----------|------------------------|
| Postgres  | `pgvector/pgvector:pg16` |
| Qdrant    | `qdrant/qdrant:v1.17.1` |
| n8n       | `n8nio/n8n:2.17.0`     |
| Khoj/Mem0/Planka | `latest` (pin to digest after first `docker compose pull`) |

## Git (personal GitHub)

```bash
cd ~/projects/memory-engine
git init
./scripts/init-git-personal.sh
# Then: git add / commit / remote / push
```

Never commit `.env`. Use `.env.example` only for key names.

## n8n workflows

Build in UI per [docs/OPERATIONS.md](docs/OPERATIONS.md) §Phase 7. Export JSON into `n8n/workflows/` and commit.
