#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

codex exec "You are the intake coordinator. Read ROLES.md, SPEC.md, TASKS.yaml, and STATE.json.
1) Interview the user to gather goals, constraints, success criteria, and context.
2) Define required roles and prompts in ROLES.md based on the user's needs.
3) Update SPEC.md with clear goals, requirements, and acceptance criteria.
4) Ask concise questions; if missing info, leave TODOs in ROLES.md/SPEC.md.
5) When intake is complete, set STATE.json.state to SPEC_READY.
6) Do not implement product code. Do not set STATE.json to RUNNING."
