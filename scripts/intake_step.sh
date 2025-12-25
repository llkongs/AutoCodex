#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

REQUIRE_CONFIRMATIONS="$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path('STATE.json').read_text())
print(str(bool(data.get('require_confirmations', False))).lower())
PY
)"

if [ -s "INTAKE_ANSWERS.md" ]; then
  codex exec --full-auto "You are the intake coordinator. Read INTAKE_ANSWERS.md, ROLES.md, SPEC.md, TASKS.yaml, and STATE.json.
1) Use the answers to define required roles and prompts in ROLES.md.
2) Update SPEC.md with clear goals, requirements, and acceptance criteria.
3) If any confirmation is still missing:
   - If require_confirmations is true, write ONLY the remaining questions to INTAKE_QUESTIONS.md, clear INTAKE_ANSWERS.md to a blank template, and set STATE.json.state to INTAKE_WAITING.
   - If require_confirmations is false, proceed with reasonable assumptions, note them in SPEC.md/ROLES.md, clear INTAKE_QUESTIONS.md, and set STATE.json.state to SPEC_READY.
4) If intake is complete, clear INTAKE_QUESTIONS.md and set STATE.json.state to SPEC_READY.
5) Do not implement product code. Do not set STATE.json to RUNNING.
6) require_confirmations=${REQUIRE_CONFIRMATIONS}"
else
  python3 - <<'PY'
from pathlib import Path
import time

answers = Path("INTAKE_ANSWERS.md")
if answers.exists() and answers.read_text().strip():
    history = Path("INTAKE_HISTORY.md")
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    history.write_text(history.read_text() + f"\n\n## Archived {stamp}\n\n" + answers.read_text())
answers.write_text("# Intake Answers\n\n")
PY

  codex exec --full-auto "You are the intake coordinator. Read ROLES.md, SPEC.md, TASKS.yaml, and STATE.json.
1) Generate a concise list of questions needed to gather goals, constraints, success criteria, and context.
2) Write the questions to INTAKE_QUESTIONS.md.
3) Reset INTAKE_ANSWERS.md to a blank template matching the questions.
4) Set STATE.json.state to INTAKE_WAITING.
5) Do not implement product code. Do not set STATE.json to RUNNING."
fi
