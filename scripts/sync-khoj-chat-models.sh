#!/usr/bin/env bash
# Run from repo root (same directory as docker-compose.yml).
# Feeds the sync script via stdin so the Khoj image does not need a bind-mount.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/khoj_sync_lmstudio_chat_models.py"
cd "$ROOT"

if [[ ! -f "$SCRIPT" ]]; then
  echo "error: missing $SCRIPT" >&2
  exit 1
fi

exec docker compose exec -T khoj env PYTHONPATH=/app/src python3 - "$@" < "$SCRIPT"
