#!/usr/bin/env bash
# Run once inside ~/projects/memory-engine after git init.
# Uses repo-local config so your work GitHub global settings are unchanged.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

read -r -p "Personal Git user.name: " GNAME
read -r -p "Personal Git user.email (GitHub noreply ok): " GEMAIL

git config user.name "$GNAME"
git config user.email "$GEMAIL"

echo "Configured (this repo only):"
git config --show-origin user.name
git config --show-origin user.email
echo
echo "Add remote with your personal SSH host alias, e.g.:"
echo "  git remote add origin git@github.com-personal:YOUR_USER/memory-engine.git"
