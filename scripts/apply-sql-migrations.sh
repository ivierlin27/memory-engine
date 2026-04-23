#!/usr/bin/env bash
# Apply SQL migrations from postgres/migrations against the running postgres container.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="${ROOT_DIR}/postgres/migrations"
CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-memory-postgres}"
DB_USER="${POSTGRES_USER:-memory}"
DB_NAME="${POSTGRES_DB:-memory}"

if [[ ! -d "${MIGRATIONS_DIR}" ]]; then
  echo "No migrations directory found: ${MIGRATIONS_DIR}" >&2
  exit 1
fi

shopt -s nullglob
files=("${MIGRATIONS_DIR}"/*.sql)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No SQL migrations found in ${MIGRATIONS_DIR}"
  exit 0
fi

for file in "${files[@]}"; do
  echo "Applying migration: $(basename "${file}")"
  docker exec -i "${CONTAINER_NAME}" psql -v ON_ERROR_STOP=1 -U "${DB_USER}" -d "${DB_NAME}" < "${file}"
done

echo "All migrations applied."
