#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

if [ -s "INTAKE_ANSWERS.md" ]; then
  codex exec "You are the intake coordinator. Read INTAKE_ANSWERS.md, ROLES.md, SPEC.md, TASKS.yaml, and STATE.json.
1) Use the answers to define required roles and prompts in ROLES.md.
2) Update SPEC.md with clear goals, requirements, and acceptance criteria.
3) If answers are incomplete, leave TODOs in ROLES.md/SPEC.md.
4) When intake is complete, set STATE.json.state to SPEC_READY.
5) Do not implement product code. Do not set STATE.json to RUNNING."
else
  codex exec "You are the intake coordinator. Read ROLES.md, SPEC.md, TASKS.yaml, and STATE.json.
1) Generate a concise list of questions needed to gather goals, constraints, success criteria, and context.
2) Write the questions to INTAKE_QUESTIONS.md.
3) Set STATE.json.state to INTAKE_WAITING.
4) Do not implement product code. Do not set STATE.json to RUNNING."
fi
