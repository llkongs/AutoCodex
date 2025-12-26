#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: bash scripts/init_project.sh [project-name]"
  exit 0
fi

if echo "$BASE_DIR" | grep -q "/projects/"; then
  echo "[init] run this script from the repo root, not inside projects/."
  exit 1
fi

PROJECTS_DIR="$BASE_DIR/projects"
mkdir -p "$PROJECTS_DIR"

timestamp="$(date +%Y%m%d-%H%M%S)"
raw_name="${1:-project-$timestamp}"

if echo "$raw_name" | grep -qi "template"; then
  echo "[init] project name contains 'template'; choose another name."
  exit 1
fi

target="$PROJECTS_DIR/$raw_name"
if [ -e "$target" ]; then
  i=2
  while [ -e "${target}-$i" ]; do
    i=$((i + 1))
  done
  target="${target}-$i"
fi

mkdir -p "$target"

for file in AGENTS.md DIAGNOSE_AGENT.md SPEC.md TASKS.yaml STATE.json README.md ROLES.md START_HERE.md; do
  cp "$BASE_DIR/$file" "$target/"
done
cp -R "$BASE_DIR/scripts" "$target/"
mkdir -p "$target/logs"

python3 - <<PY
import json
from pathlib import Path
path = Path("$target/STATE.json")
data = json.loads(path.read_text())
data["state"] = "INTAKE_READY"
data["role"] = None
data["run_id"] = None
data["started_at"] = None
data["updated_at"] = None
data["heartbeat_at"] = None
data["last_error"] = None
data["diagnosis_done"] = False
data["resume_state"] = None
data["diagnosis"] = None
data["interactive_mode"] = True
data["auto_run"] = False
data["auto_run_pid"] = None
data["plan_locked"] = False
data["review_every_n_tasks"] = 5
data["require_confirmations"] = True
path.write_text(json.dumps(data, indent=2))
PY

echo "$target"
