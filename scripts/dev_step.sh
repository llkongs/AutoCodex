#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

codex exec --full-auto "You are the developer. Read TASKS.yaml and STATE.json.
1) Pick the highest priority unblocked task and implement it.
2) If notes/context_snapshot.md exists, read it first and use it to avoid rereading large materials.
3) Run the verification command(s) for the task (or the project's default tests if defined).
4) Update TASKS.yaml status and add notes if needed.
5) If you set STATE.json to REVIEW_READY, also add review_items with the file paths that should be reviewed.
6) Update STATE.json to SPEC_READY, REVIEW_READY, or DONE depending on outcome.
7) If verification fails, set STATE.json to ERROR with a short error message.
8) Update notes/context_snapshot.md to summarize progress, key files, and next steps.
9) Do not set STATE.json to RUNNING."
