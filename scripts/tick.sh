#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

if [ -f "$BASE_DIR/TEMPLATE_ROOT" ]; then
  echo "[tick] template root marker detected; refusing to run."
  exit 0
fi

BASE_NAME="$(basename "$BASE_DIR")"
if echo "$BASE_NAME" | grep -qi "template"; then
  echo "[tick] template directory detected ($BASE_NAME); refusing to run."
  exit 0
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
export RUN_ID
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/tick-$RUN_ID.log"

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
    bash scripts/intake_step.sh 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    append_event
    ;;
  SPEC_READY)
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
    bash scripts/po_step.sh 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    append_event
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
    set +e
    bash scripts/dev_step.sh 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    append_event
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
    bash scripts/diagnose_step.sh 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    export EXIT_CODE
    set -e
    append_event
    ;;
  RUNNING|REVIEW_READY|DONE|ERROR)
    echo "[tick] no action for state=$state" | tee -a "$LOG_FILE"
    ;;
  *)
    echo "[tick] unknown state=$state" | tee -a "$LOG_FILE"
    ;;
esac
