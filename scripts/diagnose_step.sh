#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

codex exec --full-auto "Read DIAGNOSE_AGENT.md and follow its instructions."
