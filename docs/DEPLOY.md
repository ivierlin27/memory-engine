# Deploy sequence

## Phase 1 — Proxmox LXC

1. SSH to Proxmox (configure keys for `root@proxmox.dev-path.org` if not already).
2. `pvesh get /nodes/$(hostname)/status` — confirm ~6–7GB free RAM for the new CT.
3. Install the LXC template, then set `UBUNTU_TEMPLATE` in `scripts/lxc.env` to the **exact** `STORAGE:vztmpl/filename.tar.zst` Proxmox expects:
   ```bash
   pveam update
   pveam available | grep -i ubuntu-24
   pveam download local ubuntu-24.04-standard_XXX_amd64.tar.zst   # use the AVAILABLE filename
   pveam list local    # verify; copy the full name into UBUNTU_TEMPLATE
   ```
   If `pveam download local ...` fails, check **Datacenter → Storage**: the `vztmpl` content type must be enabled on `local` (or use that storage’s name instead of `local`).
4. Copy `scripts/lxc.env.example` → `scripts/lxc.env` on the Proxmox host (or edit locally and `scp` the file).
5. Run `bash scripts/provision-lxc-on-proxmox.sh` **on the Proxmox host** from a checkout of this repo, or paste the script.
6. If static IP does not apply (netplan), fix networking inside the CT manually.
7. Pi-hole: `memory-engine.dev-path.org` → LXC IP.

## Phase 2 — Sync stack

On Mac, from repo root:

```bash
./scripts/sync-to-lxc.sh root@memory-engine.dev-path.org
ssh root@memory-engine.dev-path.org
cd /opt/memory-engine
docker compose up -d
docker compose ps
```

## Phases 3–10

Follow [OPERATIONS.md](OPERATIONS.md) for LM Studio, NPM, Khoj, Planka, n8n, MCP, iOS, backup, and UFW.
