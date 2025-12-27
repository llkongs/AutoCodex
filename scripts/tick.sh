#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR=""
if [ "${1:-}" = "--project" ]; then
  PROJECT_DIR="${2:-}"
  if [ -z "$PROJECT_DIR" ]; then
    echo "[tick] --project requires a path."
    exit 1
  fi
  if [ "$PROJECT_DIR" != /* ]; then
    PROJECT_DIR="$BASE_DIR/$PROJECT_DIR"
  fi
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "[tick] project path not found: $PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
else
  if [ -f "$BASE_DIR/TEMPLATE_ROOT" ] && [ "$(pwd)" = "$BASE_DIR" ]; then
    echo "[tick] template root marker detected; use --project."
    exit 0
  fi
fi

PROJECT_DIR="$(pwd)"
if [ -f "$PROJECT_DIR/TEMPLATE_ROOT" ]; then
  echo "[tick] template root marker detected; refusing to run."
  exit 0
fi

BASE_NAME="$(basename "$PROJECT_DIR")"
if echo "$BASE_NAME" | grep -qi "template"; then
  echo "[tick] template directory detected ($BASE_NAME); refusing to run."
  exit 0
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
export RUN_ID
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/tick-$RUN_ID.log"

start_heartbeat() {
  local pid="$1"
  (
    while kill -0 "$pid" 2>/dev/null; do
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['heartbeat_at'] = now
data['updated_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
      sleep 30
    done
  ) &
  echo $!
}

update_heartbeat() {
  python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['heartbeat_at'] = now
data['updated_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
}

is_interactive() {
  python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path('STATE.json').read_text())
print(str(bool(data.get('interactive_mode', True))).lower())
PY
}

should_interrupt() {
  if [ -f "notes/interrupt.flag" ] && [ "$(is_interactive)" = "true" ]; then
    return 0
  fi
  return 1
}

auto_approve_outline_if_needed() {
  if [ "$(is_interactive)" = "true" ]; then
    return
  fi
  python3 - <<'PY'
from pathlib import Path
import re, time

tasks_path = Path("TASKS.yaml")
if not tasks_path.exists():
    raise SystemExit

text = tasks_path.read_text()
if "Outline approval checkpoint" not in text:
    raise SystemExit

lines = text.splitlines()
out = []
in_target = False
changed = False
for line in lines:
    if re.match(r"^\s*-\s+id:\s*T10\b", line) or "Outline approval checkpoint" in line:
        in_target = True
    if in_target and re.match(r"^\s*status:\s*blocked\b", line):
        out.append(line.replace("status: blocked", "status: done"))
        changed = True
        in_target = False
        continue
    out.append(line)
    if in_target and re.match(r"^\s*-\s+id:\s*", line) and "T10" not in line:
        in_target = False

if changed:
    tasks_path.write_text("\n".join(out) + "\n")
    notes = Path("notes")
    notes.mkdir(parents=True, exist_ok=True)
    approval = notes / "outline_approval.md"
    if not approval.exists():
        approval.write_text(f"# Outline Approval\n\nAuto-approved (interactive_mode=false) at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
PY
}

wait_for_review() {
  local approval_file="notes/review_approval.md"
  if [ "$(is_interactive)" != "true" ]; then
    python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'DEV_READY'
data['role'] = None
data['run_id'] = None
data['started_at'] = None
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
    return
  fi
  python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'REVIEW_WAITING'
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY

  while true; do
    if [ -s "$approval_file" ]; then
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'DEV_READY'
data['role'] = None
data['run_id'] = None
data['started_at'] = None
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
      break
    fi
    state_now="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
    if [ "$state_now" != "REVIEW_WAITING" ]; then
      break
    fi
    update_heartbeat
    sleep 10
  done
}

wait_for_interact() {
  local resume="$1"
  python3 - <<'PY'
import json, time, os
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'PAUSE_INTERACT'
data['resume_state'] = os.environ.get('RESUME_STATE', '')
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY

  while true; do
    state_now="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
    if [ "$state_now" != "PAUSE_INTERACT" ]; then
      break
    fi
    update_heartbeat
    sleep 10
  done
}
ACTION="$(python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())

if data.get('state') == 'DONE':
    print('done')
    raise SystemExit

data['heartbeat_at'] = now
data['updated_at'] = now

action = 'none'
if data.get('state') == 'RUNNING':
    started = int(data.get('started_at') or 0)
    timeout = int(data.get('timeout_sec') or 0)
    if timeout and started and now - started > timeout:
        role = data.get('role')
        data['last_error'] = 'timeout'
        if data.get('diagnosis_done'):
            data['state'] = 'ERROR'
            data['last_error'] = 'timeout_after_diagnosis'
        else:
            data['state'] = 'DIAGNOSE_READY'
            if role == 'PO':
                data['resume_state'] = 'SPEC_READY'
            elif role == 'INTAKE':
                data['resume_state'] = 'INTAKE_READY'
            else:
                data['resume_state'] = 'DEV_READY'
        path.write_text(json.dumps(data, indent=2))
        print('timeout')
        raise SystemExit

if data.get('state') in ('INTAKE_READY', 'SPEC_READY', 'DEV_READY'):
    action = data['state']
    if data.get('last_error') is None:
        data['diagnosis_done'] = False
        data['resume_state'] = None

if data.get('state') == 'REVIEW_WAITING':
    action = 'none'

if data.get('state') == 'PAUSE_INTERACT':
    action = 'none'

path.write_text(json.dumps(data, indent=2))
print(action)
PY
)"

if [ "$ACTION" = "done" ]; then
  echo "[tick] state=DONE; tasks completed; stopping." | tee -a "$LOG_FILE"
  exit 0
fi

if [ "$ACTION" = "timeout" ]; then
  echo "[tick] timeout detected; state updated." | tee -a "$LOG_FILE"
  exit 0
fi

LOCKDIR=".agent_lock"
if [ -d "$LOCKDIR" ]; then
  current_state="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
  if [ "$current_state" != "RUNNING" ]; then
    rmdir "$LOCKDIR" 2>/dev/null || true
  fi
fi
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCKDIR"' EXIT

state="$(python3 - <<PY
import json
with open('STATE.json','r') as f:
    print(json.load(f).get('state',''))
PY
)"

auto_approve_outline_if_needed

echo "[tick] state=$state run_id=$RUN_ID" | tee -a "$LOG_FILE"

append_event() {
  python3 - <<'PY'
import json, time
from pathlib import Path
import os, re

state_path = Path('STATE.json')
tasks_path = Path('TASKS.yaml')
log_file = os.environ.get('LOG_FILE', '')
run_id = os.environ.get('RUN_ID', '')
state_before = os.environ.get('STATE_BEFORE', '')
role = os.environ.get('ROLE_NAME', '')
exit_code = int(os.environ.get('EXIT_CODE', '0') or 0)

data = json.loads(state_path.read_text()) if state_path.exists() else {}
state_after = data.get('state', '')

done = 0
total = 0
if tasks_path.exists():
  for line in tasks_path.read_text().splitlines():
    if re.match(r"^\s*status:\s*", line):
      total += 1
      if re.match(r"^\s*status:\s*done\b", line):
        done += 1

event = {
  "ts": int(time.time()),
  "run_id": run_id,
  "role": role,
  "state_before": state_before,
  "state_after": state_after,
  "exit_code": exit_code,
  "tasks_done": done,
  "tasks_total": total,
  "log_file": Path(log_file).name if log_file else None,
}

events_path = Path('logs') / 'events.ndjson'
events_path.parent.mkdir(parents=True, exist_ok=True)
with events_path.open('a', encoding='utf-8') as f:
  f.write(json.dumps(event, ensure_ascii=False) + "\n")
PY
}

case "$state" in
  INTAKE_READY)
    if [ "$(is_interactive)" != "true" ]; then
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'SPEC_READY'
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
      echo "[tick] interactive_mode=false; skipping intake." | tee -a "$LOG_FILE"
      exit 0
    fi
    STATE_BEFORE="$state"
    ROLE_NAME="INTAKE"
    export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
    python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'INTAKE'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
data['last_error'] = None
path.write_text(json.dumps(data, indent=2))
PY
    set +e
    bash "$BASE_DIR/scripts/intake_step.sh" --project "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE" &
    run_pid=$!
    hb_pid=$(start_heartbeat "$run_pid")
    wait "$run_pid"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    kill "$hb_pid" 2>/dev/null || true
    append_event
    ;;
  SPEC_READY)
    plan_locked="$(python3 - <<'PY'
import json
from pathlib import Path
print(str(bool(json.loads(Path('STATE.json').read_text()).get('plan_locked', False))).lower())
PY
)"
    if [ "$plan_locked" = "true" ]; then
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'DEV_READY'
data['role'] = None
data['run_id'] = None
data['started_at'] = None
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
      echo "[tick] plan_locked=true; skipping PO." | tee -a "$LOG_FILE"
      exit 0
    fi
    STATE_BEFORE="$state"
    ROLE_NAME="PO"
    export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
    python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'PO'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
data['last_error'] = None
path.write_text(json.dumps(data, indent=2))
PY
    set +e
    bash "$BASE_DIR/scripts/po_step.sh" --project "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE" &
    run_pid=$!
    hb_pid=$(start_heartbeat "$run_pid")
    wait "$run_pid"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    kill "$hb_pid" 2>/dev/null || true
    append_event
    if should_interrupt; then
      RESUME_STATE="DEV_READY"
      export RESUME_STATE
      wait_for_interact "$RESUME_STATE"
    fi
    next_state="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
    if [ "$next_state" = "DEV_READY" ]; then
      STATE_BEFORE="DEV_READY"
      ROLE_NAME="DEV"
      export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'DEV'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
data['last_error'] = None
path.write_text(json.dumps(data, indent=2))
PY
      set +e
      bash "$BASE_DIR/scripts/dev_step.sh" --project "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE" &
      run_pid=$!
      hb_pid=$(start_heartbeat "$run_pid")
      wait "$run_pid"
      EXIT_CODE=${PIPESTATUS[0]}
      export EXIT_CODE
      set -e
      kill "$hb_pid" 2>/dev/null || true
      append_event
      if should_interrupt; then
        RESUME_STATE="DEV_READY"
        export RESUME_STATE
        wait_for_interact "$RESUME_STATE"
      fi
      next_state="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
      if [ "$next_state" = "REVIEW_READY" ]; then
        wait_for_review
      fi
    fi
    ;;
  DEV_READY)
    STATE_BEFORE="$state"
    ROLE_NAME="DEV"
    export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
    python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'DEV'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
data['last_error'] = None
path.write_text(json.dumps(data, indent=2))
PY
    max_chain="${DEV_CHAIN_LIMIT:-3}"
    chain_count=0
    while true; do
      set +e
      bash "$BASE_DIR/scripts/dev_step.sh" --project "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE" &
      run_pid=$!
      hb_pid=$(start_heartbeat "$run_pid")
      wait "$run_pid"
      EXIT_CODE=${PIPESTATUS[0]}
      export EXIT_CODE
      set -e
      kill "$hb_pid" 2>/dev/null || true
      append_event
      next_state="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
      if [ "$next_state" = "REVIEW_READY" ]; then
        wait_for_review
        next_state="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('STATE.json').read_text()).get('state',''))
PY
)"
      fi
      if [ "$next_state" != "DEV_READY" ]; then
        break
      fi
      chain_count=$((chain_count + 1))
      if [ "$chain_count" -ge "$max_chain" ]; then
        break
      fi
      STATE_BEFORE="DEV_READY"
      ROLE_NAME="DEV"
      export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
      python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'DEV'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
data['last_error'] = None
path.write_text(json.dumps(data, indent=2))
PY
    done
    ;;
  DIAGNOSE_READY)
    STATE_BEFORE="$state"
    ROLE_NAME="DIAGNOSE"
    export STATE_BEFORE ROLE_NAME LOG_FILE RUN_ID
    python3 - <<'PY'
import json, time
from pathlib import Path

path = Path('STATE.json')
data = json.loads(path.read_text())
now = int(time.time())
data['state'] = 'RUNNING'
data['role'] = 'DIAGNOSE'
data['run_id'] = __import__('os').environ.get('RUN_ID', '')
data['started_at'] = now
data['updated_at'] = now
data['heartbeat_at'] = now
path.write_text(json.dumps(data, indent=2))
PY
    set +e
    bash "$BASE_DIR/scripts/diagnose_step.sh" --project "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE" &
    run_pid=$!
    hb_pid=$(start_heartbeat "$run_pid")
    wait "$run_pid"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    kill "$hb_pid" 2>/dev/null || true
    append_event
    ;;
  RUNNING|REVIEW_READY|DONE|ERROR|PAUSED|INTAKE_WAITING|REVIEW_WAITING|PAUSE_INTERACT)
    echo "[tick] no action for state=$state" | tee -a "$LOG_FILE"
    ;;
  *)
    echo "[tick] unknown state=$state" | tee -a "$LOG_FILE"
    ;;
esac
