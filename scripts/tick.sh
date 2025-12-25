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
            data['resume_state'] = 'SPEC_READY' if role == 'PO' else 'DEV_READY'
        path.write_text(json.dumps(data, indent=2))
        print('timeout')
        raise SystemExit

if data.get('state') in ('SPEC_READY', 'DEV_READY'):
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

case "$state" in
  SPEC_READY)
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
    bash scripts/po_step.sh 2>&1 | tee -a "$LOG_FILE"
    ;;
  DEV_READY)
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
    bash scripts/dev_step.sh 2>&1 | tee -a "$LOG_FILE"
    ;;
  DIAGNOSE_READY)
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
    bash scripts/diagnose_step.sh 2>&1 | tee -a "$LOG_FILE"
    ;;
  RUNNING|REVIEW_READY|DONE|ERROR)
    echo "[tick] no action for state=$state" | tee -a "$LOG_FILE"
    ;;
  *)
    echo "[tick] unknown state=$state" | tee -a "$LOG_FILE"
    ;;
esac
