#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR=""
if [ "${1:-}" = "--project" ]; then
  PROJECT_DIR="${2:-}"
  if [ -z "$PROJECT_DIR" ]; then
    echo "[po] --project requires a path."
    exit 1
  fi
  if [ "$PROJECT_DIR" != /* ]; then
    PROJECT_DIR="$BASE_DIR/$PROJECT_DIR"
  fi
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "[po] project path not found: $PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
else
  if [ ! -f "STATE.json" ]; then
    echo "[po] STATE.json not found; use --project."
    exit 1
  fi
fi

codex exec --full-auto "You are the PO/planner. Read SPEC.md, TASKS.yaml, STATE.json, and notes/interaction_notes.md if it exists.
If STATE.json.interactive_mode is false, do not ask the user questions or require approvals; proceed with reasonable assumptions.
1) Refine TASKS.yaml into small executable steps with clear DoD and verify instructions.
2) Keep tasks ordered by priority and respect dependencies.
3) Update STATE.json state to DEV_READY when planning is complete.
4) Do not ask the user for confirmation; make reasonable assumptions and note them.
5) Set STATE.json.plan_locked = true after planning to avoid re-planning loops.
6) Update notes/context_snapshot.md with the updated plan, assumptions, and next steps.
7) Do not implement product code.
8) Do not set STATE.json to RUNNING."
