#!/usr/bin/env bash
# Runs once on empty Postgres data dir (before *.sql). Creates dedicated DBs so n8n and Planka
# never share tables with each other or with Khoj/Mem0/custom schema in `memory`.
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname postgres <<-EOSQL
CREATE DATABASE n8n;
CREATE DATABASE planka;
EOSQL
