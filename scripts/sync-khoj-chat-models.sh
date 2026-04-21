#!/usr/bin/env bash
# Run from repo root (same directory as docker-compose.yml).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec docker compose exec -T khoj python3 /app/scripts/khoj_sync_lmstudio_chat_models.py "$@"
