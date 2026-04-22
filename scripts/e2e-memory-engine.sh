#!/usr/bin/env bash
# End-to-end checks for n8n "ME ·" workflows (happy paths over HTTP + optional LXC execute).
#
# From your Mac (or any client that can reach n8n):
#   export N8N_BASE="https://n8n.dev-path.org"   # your N8N_EDITOR_BASE_URL / origin, no trailing slash
#   export PLANKA_REJECTED_LIST_ID="<uuid-from-planka>"   # required for synthetic Planka webhook step
#   ./scripts/e2e-memory-engine.sh
#
# Optional:
#   N8N_BASIC_AUTH="user:pass"   — only if curl needs -u for your setup (many installs need no auth for /webhook/*)
#   RUN_DIGEST=1 N8N_SSH="root@memory-engine.dev-path.org" — SSH to host that runs Docker and `memory-n8n`; runs Weekly digest via CLI (needs LM Studio for success)
#   SKIP_DIGEST=1 — skip digest even if N8N_SSH is set
#
set -euo pipefail

N8N_BASE="${N8N_BASE:-}"
if [[ -z "${N8N_BASE}" ]]; then
  printf 'Set N8N_BASE to your n8n origin (example: export N8N_BASE="https://n8n.dev-path.org")\n' >&2
  exit 1
fi
N8N_BASE="${N8N_BASE%/}"

CURL=(curl -sS -w "\n%{http_code}")
if [[ -n "${N8N_BASIC_AUTH:-}" ]]; then
  CURL+=(-u "${N8N_BASIC_AUTH}")
fi

jq_ok() {
  command -v jq >/dev/null 2>&1
}

say() { printf '%s\n' "$*"; }

say "=== ME · Ingest (${N8N_BASE}/webhook/ingest) ==="
INGEST_PAYLOAD="$(printf '%s' '{"type":"text","content":"e2e ingest '"$(date -u +%Y%m%dT%H%M%SZ)"'","source":"e2e"}')"
resp="$("${CURL[@]}" -X POST "${N8N_BASE}/webhook/ingest" \
  -H "Content-Type: application/json" \
  -d "${INGEST_PAYLOAD}")"
code="$(printf '%s' "${resp}" | tail -n1)"
body="$(printf '%s' "${resp}" | sed '$d')"
say "HTTP ${code}"
say "${body}"
if [[ "${code}" != "200" ]]; then
  say "FAILED: ingest expected HTTP 200" >&2
  exit 1
fi
PLANKA_CARD_ID=""
INBOX_ID=""
if jq_ok; then
  PLANKA_CARD_ID="$(printf '%s' "${body}" | jq -r '.planka_card_id // empty')"
  INBOX_ID="$(printf '%s' "${body}" | jq -r '.inbox_id // empty')"
fi

say ""
say "=== ME · Session end (${N8N_BASE}/webhook/session-end) ==="
resp="$("${CURL[@]}" -X POST "${N8N_BASE}/webhook/session-end" \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"e2e\",\"raw_summary\":\"Weekly themes test session $(date -u +%Y-%m-%d)\"}")"
code="$(printf '%s' "${resp}" | tail -n1)"
body="$(printf '%s' "${resp}" | sed '$d')"
say "HTTP ${code}"
say "${body}"
if [[ "${code}" != "200" ]]; then
  say "FAILED: session-end expected HTTP 200" >&2
  exit 1
fi

say ""
Rejected="${PLANKA_REJECTED_LIST_ID:-}"
if [[ -z "${Rejected}" ]]; then
  say "=== ME · Planka card moved — SKIP (set PLANKA_REJECTED_LIST_ID to exercise) ==="
elif [[ -z "${PLANKA_CARD_ID}" ]]; then
  say "=== ME · Planka card moved — SKIP (ingest response had no planka_card_id; re-import updated ingest workflow on n8n) ==="
else
  say "=== ME · Planka card moved (${N8N_BASE}/webhook/planka-card-moved) synthetic payload ==="
  if command -v jq >/dev/null 2>&1; then
    syn="$(jq -nc --arg cid "${PLANKA_CARD_ID}" --arg lid "${Rejected}" '{item:{id:$cid,listId:$lid}}')"
  else
    syn="{\"item\":{\"id\":\"${PLANKA_CARD_ID}\",\"listId\":\"${Rejected}\"}}"
  fi
  resp="$("${CURL[@]}" -X POST "${N8N_BASE}/webhook/planka-card-moved" \
    -H "Content-Type: application/json" \
    -d "${syn}")"
  code="$(printf '%s' "${resp}" | tail -n1)"
  body="$(printf '%s' "${resp}" | sed '$d')"
  say "HTTP ${code}"
  say "${body}"
  if [[ "${code}" != "200" ]]; then
    say "FAILED: planka-card-moved expected HTTP 200" >&2
    exit 1
  fi
  if jq_ok && [[ "$(printf '%s' "${body}" | jq -r '.handled // empty')" != "rejected" ]]; then
    say "NOTE: handled was not \"rejected\" — check Extract IDs mapping against real Planka payloads (_raw_sample in executions)." >&2
  fi
fi

say ""
if [[ "${SKIP_DIGEST:-}" == "1" ]]; then
  say "=== ME · Weekly digest — SKIP (SKIP_DIGEST=1) ==="
elif [[ "${RUN_DIGEST:-}" == "1" ]] && [[ -n "${N8N_SSH:-}" ]]; then
  say "=== ME · Weekly digest — n8n execute on ${N8N_SSH} (needs LM Studio + optional ntfy) ==="
  # shellcheck disable=SC2029
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "${N8N_SSH}" \
    'docker exec memory-n8n n8n execute --id=a1b0a1b0-0001-4000-8000-000000000004' 2>&1)" || true
  say "${out}"
  if printf '%s' "${out}" | grep -q '5679 is already in use'; then
    say "NOTE: \`n8n execute\` cannot bind its task broker while the main n8n server is running in the same container." >&2
    say "Test digest from the UI (Open workflow → Execute workflow / wait for cron) or run execute on a stopped instance." >&2
  elif printf '%s' "${out}" | grep -qi error; then
    say "Digest execute reported an error — check LM Studio and n8n Executions." >&2
  fi
else
  say "=== ME · Weekly digest — SKIP (cron-driven; optional RUN_DIGEST=1 + N8N_SSH tries CLI — often conflicts with running server; prefer manual Execute in UI) ==="
fi

say ""
say "Passthrough checks finished. Confirm in n8n → Executions and Planka/Khoj/Mem0 as needed."
