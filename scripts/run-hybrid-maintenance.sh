#!/usr/bin/env bash
# Run the derived wiki compiler and contradiction scan from the Docker host.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

python3 "${ROOT_DIR}/scripts/wiki_compile.py"
python3 "${ROOT_DIR}/scripts/scan_contradictions.py"
