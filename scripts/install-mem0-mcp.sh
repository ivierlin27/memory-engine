#!/usr/bin/env bash
# Phase 8 — run on Mac after `uv` is installed. Edit MEM0_USER_ID and model names.
set -euo pipefail
: "${MEM0_USER_ID:=your-name}"
: "${OPENAI_MODEL:=qwen2.5-32b-instruct}"

if ! command -v claude >/dev/null 2>&1; then
  echo "Install Claude Code CLI first (claude)."
  exit 1
fi

claude mcp add --scope user --transport stdio mem0 \
  --env "MEM0_USER_ID=${MEM0_USER_ID}" \
  --env MEM0_PROVIDER=openai \
  --env OPENAI_API_KEY=lm-studio \
  --env OPENAI_BASE_URL="http://lmstudio.dev-path.org:1234/v1" \
  --env "OPENAI_MODEL=${OPENAI_MODEL}" \
  --env QDRANT_HOST=memory-engine.dev-path.org \
  --env QDRANT_PORT=6333 \
  -- uvx --from git+https://github.com/elvismdev/mem0-mcp-selfhosted.git mem0-mcp-selfhosted

echo "Run: claude mcp list"
