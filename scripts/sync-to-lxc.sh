#!/usr/bin/env bash
# From MacBook: rsync project to memory-engine LXC (see MEMORY_ENGINE_BUILD_PLAN_v2 §2.4).
set -euo pipefail
REMOTE="${1:-root@memory-engine.dev-path.org}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rsync -avz \
  --exclude '.git' \
  --exclude 'backups' \
  "${ROOT}/" "${REMOTE}:/opt/memory-engine/"

echo "Synced to ${REMOTE}:/opt/memory-engine/"
echo "On LXC: cd /opt/memory-engine && docker compose pull && docker compose up -d"
