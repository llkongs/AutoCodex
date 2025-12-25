#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

codex exec --full-auto "You are the developer. Read TASKS.yaml and STATE.json.
1) Pick the highest priority unblocked task and implement it.
2) Run the verification command(s) for the task (or the project's default tests if defined).
3) Update TASKS.yaml status and add notes if needed.
4) Update STATE.json to SPEC_READY, REVIEW_READY, or DONE depending on outcome.
5) If verification fails, set STATE.json to ERROR with a short error message.
6) Do not set STATE.json to RUNNING."
