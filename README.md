AI Auto Task Frame

This folder is a reusable protocol + runner scripts for Codex CLI automation.
Clone this repo, then create isolated project folders under projects/.

Start here
- Read START_HERE.md first for the quick workflow and rules.

Quick start
1) Create a new project folder under projects/:
   bash scripts/init_project.sh my-project
2) Enter the new folder:
   cd projects/my-project
3) Run intake and answer questions:
   bash scripts/tick.sh
4) When INTAKE_WAITING, answer questions (INTAKE_ANSWERS.md or web UI), then:
   bash scripts/tick.sh
   (Intake only confirms once; after that it proceeds with reasonable assumptions.)
5) Split work into TASKS.yaml with DoD and verification commands.
6) Set STATE.json to SPEC_READY or DEV_READY.
7) Run a watcher (entr/fswatch) or a timer loop to trigger scripts/tick.sh.

Status panel
- Watch current progress:
  bash scripts/status.sh --tail 50
- Refresh every second:
  watch -n 1 bash scripts/status.sh --tail 50

Web dashboard
- Start local UI server:
  python3 scripts/monitor_server.py
- Open in browser:
  http://127.0.0.1:8787
- Use the intake panel to answer questions and pause/resume projects.
- Use "Run Tick" to trigger a new run and watch logs streaming in the log panel.
- DEV auto-continues for up to 3 tasks per tick (override with DEV_CHAIN_LIMIT).
- While a run is active, heartbeat_at is updated every 30 seconds.
- notes/context_snapshot.md is updated by PO/DEV for restart fallback.
- Interaction panel writes to notes/interaction_notes.md and supports interrupt/continue.
- interactive_mode=true enables intake/review; set false to skip them.

Project init
- Default name is project-YYYYMMDD-HHMMSS if no name is provided.
- If the folder exists, a numeric suffix is added (e.g. my-project-2).
- Names containing "template" are rejected to avoid template guard failures.
- Run init_project.sh only from the repo root (not inside projects/).
- Do not manually copy the repo; always initialize via the script.
- ROLES.md is copied into each project to define required roles first.
- New projects start at INTAKE_READY to gather requirements and roles.

Project isolation
- Each project lives under projects/ in its own folder.
- STATE.json, TASKS.yaml, logs/, and .agent_lock are local to that folder.

Template safety
- If TEMPLATE_ROOT exists, scripts/tick.sh will refuse to run in the repo root.
- If the folder name contains \"template\" (case-insensitive), scripts/tick.sh will refuse to run.
- These checks prevent accidental runs inside the reusable framework/template folder.

Reliability and timeouts
- scripts/tick.sh updates STATE.json timestamps on every run.
- A running job is marked RUNNING with a 1800s timeout by default.
- On timeout, it runs a diagnosis step once, then retries once.
- If it times out again after diagnosis, it moves to ERROR.

Process diagram (no STATE.json trigger)
```mermaid
flowchart TD
  classDef auto fill:#d6f5d6,stroke:#2d7d46,stroke-width:1px,color:#123d1d;
  classDef manual fill:#ffd6d6,stroke:#b11d1d,stroke-width:1px,color:#5c1111;

  TR1[触发器A：SPEC.md 更新<br/>文件监听触发 tick.sh]
  TR2[触发器B：TASKS.yaml 更新<br/>文件监听触发 tick.sh]
  TR3[触发器C：定时器<br/>每 N 秒触发 tick.sh]

  TR1 --> T1[tick.sh 启动<br/>进入项目根目录]
  TR2 --> T1
  TR3 --> T1

  T1 --> T2{目录名包含 template?}
  T2 -- 是 --> X[终止执行<br/>模板保护触发，需人工处理]:::manual
  T2 -- 否 --> T3[读取 STATE.json]

  T3 --> T4{state == DONE?}
  T4 -- 是 --> X3[终止执行<br/>记录完成日志并退出]:::manual
  T4 -- 否 --> T5[写入 heartbeat_at / updated_at]

  T5 --> T6{state == RUNNING?}
  T6 -- 是 --> T7[检查超时<br/>now-started_at > timeout_sec?]
  T7 -- 否 --> Z1[等待下一轮触发]:::auto
  T7 -- 是 --> T8[超时处理<br/>若未诊断则设 DIAGNOSE_READY，否则设 ERROR] --> Z2[等待下一轮触发]:::auto

  T6 -- 否 --> T9{state 类型?}
  T9 -- SPEC_READY --> P0[进入 RUNNING(role=PO)] --> P1[执行 po_step.sh<br/>更新 TASKS.yaml/STATE.json] --> P2{更新了 SPEC/TASKS?}
  T9 -- DEV_READY --> D0[进入 RUNNING(role=DEV)] --> D1[执行 dev_step.sh<br/>实现/验证/更新状态] --> D2{更新了 SPEC/TASKS?}
  T9 -- DIAGNOSE_READY --> G0[进入 RUNNING(role=DIAGNOSE)] --> G1[执行 diagnose_step.sh<br/>诊断并调整] --> G2{更新了 SPEC/TASKS?}
  T9 -- REVIEW_READY --> Z3[等待下一轮触发<br/>人工验收中]:::auto
  T9 -- ERROR --> X2[人工介入<br/>修复问题或调整状态]:::manual
  T9 -- UNKNOWN --> Z4[等待下一轮触发]:::auto

  P2 -- 是 --> TR1
  P2 -- 是 --> TR2
  P2 -- 否 --> TR3

  D2 -- 是 --> TR1
  D2 -- 是 --> TR2
  D2 -- 否 --> TR3

  G2 -- 是 --> TR1
  G2 -- 是 --> TR2
  G2 -- 否 --> TR3

  Z1 --> TR3
  Z2 --> TR3
  Z3 --> TR3
  Z4 --> TR3
```

STATE.json fields
- timeout_sec: per-run timeout (default 1800).
- started_at/updated_at/heartbeat_at: epoch seconds for observability.
- diagnosis_done: true after the timeout diagnosis has run.
- resume_state: where to resume after diagnosis (SPEC_READY or DEV_READY).
- diagnosis: short summary written by the diagnostician.

Suggested watcher (macOS/Linux with entr):
  ls SPEC.md TASKS.yaml STATE.json | entr -r bash scripts/tick.sh

Suggested timer loop:
  while true; do bash scripts/tick.sh; sleep 10; done

Files
- SPEC.md: product spec and acceptance criteria.
- TASKS.yaml: task queue with DoD and verification.
- STATE.json: state machine for the automation loop.
- AGENTS.md: instructions for Codex CLI runs in this folder.
- DIAGNOSE_AGENT.md: timeout diagnosis rules and allowed adjustments.
- scripts/tick.sh: scheduler that routes to PO or DEV scripts.
- scripts/po_step.sh: Codex exec prompt for planning tasks.
- scripts/dev_step.sh: Codex exec prompt for implementation.
- scripts/diagnose_step.sh: Codex exec prompt for timeout diagnosis.
