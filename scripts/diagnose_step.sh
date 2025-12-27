#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR=""
if [ "${1:-}" = "--project" ]; then
  PROJECT_DIR="${2:-}"
  if [ -z "$PROJECT_DIR" ]; then
    echo "[diagnose] --project requires a path."
    exit 1
  fi
  if [ "$PROJECT_DIR" != /* ]; then
    PROJECT_DIR="$BASE_DIR/$PROJECT_DIR"
  fi
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "[diagnose] project path not found: $PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
else
  if [ ! -f "STATE.json" ]; then
    echo "[diagnose] STATE.json not found; use --project."
    exit 1
  fi
fi

codex exec --full-auto "Read DIAGNOSE_AGENT.md and follow its instructions."
