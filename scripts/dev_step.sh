#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR=""
if [ "${1:-}" = "--project" ]; then
  PROJECT_DIR="${2:-}"
  if [ -z "$PROJECT_DIR" ]; then
    echo "[dev] --project requires a path."
    exit 1
  fi
  if [ "$PROJECT_DIR" != /* ]; then
    PROJECT_DIR="$BASE_DIR/$PROJECT_DIR"
  fi
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "[dev] project path not found: $PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
else
  if [ ! -f "STATE.json" ]; then
    echo "[dev] STATE.json not found; use --project."
    exit 1
  fi
fi

codex exec --full-auto "You are the developer. Read TASKS.yaml, STATE.json, and notes/interaction_notes.md if it exists.
If STATE.json.interactive_mode is false, do not ask the user questions or require approvals; proceed with reasonable assumptions and record them.
1) Pick the highest priority unblocked task and implement it.
2) If notes/context_snapshot.md exists, read it first and use it to avoid rereading large materials.
3) Run the verification command(s) for the task (or the project's default tests if defined).
4) Update TASKS.yaml status and add notes if needed.
5) If STATE.json.interactive_mode is false, never set REVIEW_READY; proceed to DEV_READY or DONE.
6) If interactive_mode is true, only set REVIEW_READY on milestones: when tasks_done % review_every_n_tasks == 0 or if the task explicitly requires review.
7) If you set STATE.json to REVIEW_READY, also add review_items with the file paths that should be reviewed.
8) If STATE.json.plan_locked is true, do not set SPEC_READY; use DEV_READY or DONE.
9) Update STATE.json to SPEC_READY, REVIEW_READY, DEV_READY, or DONE depending on outcome.
7) If verification fails, set STATE.json to ERROR with a short error message.
10) Update notes/context_snapshot.md to summarize progress, key files, and next steps.
11) Do not set STATE.json to RUNNING."
