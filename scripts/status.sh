#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

LANG_CODE="${STATUS_LANG:-en}"
TAIL_LINES="${STATUS_TAIL:-50}"

usage() {
  echo "Usage: bash scripts/status.sh [--lang en|zh] [--tail N]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)
      LANG_CODE="${2:-en}"
      shift 2
      ;;
    --tail)
      TAIL_LINES="${2:-50}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

label() {
  local key="$1"
  if [ "$LANG_CODE" = "zh" ]; then
    case "$key" in
      state) echo "状态";;
      role) echo "角色";;
      runtime) echo "运行时长";;
      timeout) echo "超时(秒)";;
      heartbeat) echo "心跳距今";;
      tasks) echo "任务进度";;
      diagnosis) echo "诊断";;
      log_tail) echo "最近日志";;
      log_none) echo "暂无日志";;
      *) echo "$key";;
    esac
  else
    case "$key" in
      state) echo "State";;
      role) echo "Role";;
      runtime) echo "Runtime";;
      timeout) echo "Timeout(s)";;
      heartbeat) echo "Heartbeat Age";;
      tasks) echo "Tasks";;
      diagnosis) echo "Diagnosis";;
      log_tail) echo "Latest Log Tail";;
      log_none) echo "No logs";;
      *) echo "$key";;
    esac
  fi
}

if [ ! -f STATE.json ]; then
  echo "STATE.json not found in $BASE_DIR"
  exit 1
fi

state_json="$(cat STATE.json)"
now_ts="$(date +%s)"

read_state() {
  python3 - <<PY
import json
data = json.loads("""$state_json""")
print(data.get("$1", ""))
PY
}

state="$(read_state state)"
role="$(read_state role)"
started_at="$(read_state started_at)"
timeout_sec="$(read_state timeout_sec)"
heartbeat_at="$(read_state heartbeat_at)"
diagnosis="$(read_state diagnosis)"

runtime="n/a"
if [ -n "$started_at" ] && [ "$started_at" != "None" ]; then
  runtime="$((now_ts - started_at))s"
fi

heartbeat="n/a"
if [ -n "$heartbeat_at" ] && [ "$heartbeat_at" != "None" ]; then
  heartbeat="$((now_ts - heartbeat_at))s"
fi

total_tasks="$(rg -c '^\s*status:\s*' TASKS.yaml 2>/dev/null || true)"
done_tasks="$(rg -c '^\s*status:\s*done\b' TASKS.yaml 2>/dev/null || true)"

echo "$(label state): $state"
echo "$(label role): ${role:-n/a}"
echo "$(label runtime): $runtime  |  $(label timeout): ${timeout_sec:-n/a}"
echo "$(label heartbeat): $heartbeat"
echo "$(label tasks): ${done_tasks}/${total_tasks}"
echo "$(label diagnosis): ${diagnosis:-n/a}"
echo
echo "$(label log_tail):"

latest_log="$(ls -t logs/*.log 2>/dev/null | head -n 1 || true)"
if [ -z "$latest_log" ]; then
  echo "$(label log_none)"
  exit 0
fi

tail -n "$TAIL_LINES" "$latest_log"
