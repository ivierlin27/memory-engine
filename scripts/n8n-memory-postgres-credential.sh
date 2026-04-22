#!/usr/bin/env bash
# Import the shared "Memory Postgres" credential into n8n (plaintext data object;
# n8n CLI encrypts it). Run on the LXC from the repo root after docker compose is up.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

CRED_ID="${CRED_ID:-a1c0feed-0001-4000-8000-00000000c001}"

if [[ ! -f .env ]]; then
  echo "Missing .env in ${ROOT}" >&2
  exit 1
fi

PROJECT_ID="${N8N_PROJECT_ID:-}"
if [[ -z "${PROJECT_ID}" ]]; then
  PROJECT_ID="$(docker exec memory-postgres psql -U memory -d n8n -tAc "SELECT id FROM project LIMIT 1;" 2>/dev/null || true)"
fi
if [[ -z "${PROJECT_ID}" ]]; then
  echo "Set N8N_PROJECT_ID or ensure memory-n8n / memory-postgres are running." >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

python3 <<PY
import json, re
from pathlib import Path

cred_id = "${CRED_ID}"
pw = None
for line in Path(".env").read_text().splitlines():
    m = re.match(r"^POSTGRES_PASSWORD=(.*)$", line.strip())
    if m:
        pw = m.group(1).strip().strip('"').strip("'")
        break
if not pw:
    raise SystemExit("POSTGRES_PASSWORD not found in .env")

doc = [{
    "id": cred_id,
    "name": "Memory Postgres",
    "type": "postgres",
    "data": {
        "host": "postgres",
        "port": 5432,
        "database": "memory",
        "user": "memory",
        "password": pw,
        "maxConnections": 100,
        "allowUnauthorizedCerts": False,
        "ssl": "disable",
    },
}]
Path("${TMP}").write_text(json.dumps(doc))
PY

docker cp "${TMP}" memory-n8n:/tmp/mem-pg-cred.json
docker exec memory-n8n n8n import:credentials --input=/tmp/mem-pg-cred.json --projectId="${PROJECT_ID}"
echo "Imported credential ${CRED_ID} (project ${PROJECT_ID})."
