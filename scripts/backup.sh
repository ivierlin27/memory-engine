#!/usr/bin/env bash
# Run on the LXC inside /opt/memory-engine (paths match compose).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
# shellcheck source=/dev/null
source "${ROOT_DIR}/.env"
set +a

DATE=$(date +%Y%m%d_%H%M)
BACKUP_DIR="${ROOT_DIR}/backups"
mkdir -p "$BACKUP_DIR"

docker exec memory-postgres pg_dump -U memory memory | gzip > "${BACKUP_DIR}/postgres_${DATE}.sql.gz"

curl -s -u "${ADMIN_EMAIL}:${ADMIN_PASSWORD}" \
  "http://localhost:5678/api/v1/workflows" \
  > "${BACKUP_DIR}/n8n_workflows_${DATE}.json"

find "$BACKUP_DIR" -mtime +30 -delete

echo "$(date -Iseconds): backup complete" >> "${BACKUP_DIR}/backup.log"
echo "Backup complete: ${BACKUP_DIR}/postgres_${DATE}.sql.gz"
