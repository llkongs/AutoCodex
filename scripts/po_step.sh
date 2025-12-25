#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

codex exec --full-auto "You are the PO/planner. Read SPEC.md, TASKS.yaml, STATE.json.
1) Refine TASKS.yaml into small executable steps with clear DoD and verify instructions.
2) Keep tasks ordered by priority and respect dependencies.
3) Update STATE.json state to DEV_READY when planning is complete.
4) Do not implement product code.
5) Do not set STATE.json to RUNNING."
