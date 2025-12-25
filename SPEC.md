# Spec

## Goal
Provide an initialization workflow so users can clone this framework repo and
create isolated project folders without manual copying, with an intake step
that gathers requirements and defines roles.

## Non-goals
- Building any project-specific features or tasks beyond the framework.
- Changing the core state machine logic in scripts/tick.sh.

## Requirements
- R1: Add a shell init script at scripts/init_project.sh.
- R2: The script creates a new project folder under projects/.
- R3: The script accepts an optional project name; if omitted, use
  "project-YYYYMMDD-HHMMSS".
- R4: If the target folder exists, append a numeric suffix (-2, -3, ...).
- R5: Copy the framework assets needed to run tasks:
  AGENTS.md, DIAGNOSE_AGENT.md, SPEC.md, TASKS.yaml, STATE.json, scripts/,
  README.md, and create logs/.
- R6: Refuse project names that contain "template" (case-insensitive) and
  print a clear message.
- R7: Print the created project path on success; exit non-zero on error.
- R8: Add an intake stage with a new state INTAKE_READY and script
  scripts/intake_step.sh.
- R9: Intake gathers user requirements, defines project roles, updates
  ROLES.md and SPEC.md, then sets STATE.json to SPEC_READY.
- R10: Provide a local web dashboard to view project state, tasks, and logs.

## Acceptance Criteria
- AC1: Running `bash scripts/init_project.sh` creates a new folder under
  projects/ with the expected files and directories.
- AC2: Running `bash scripts/init_project.sh myproj` creates projects/myproj,
  or projects/myproj-2 if it already exists.
- AC3: The created project folder can run `bash scripts/tick.sh` without
  tripping the template guard.
- AC4: When STATE.json is INTAKE_READY, running `bash scripts/tick.sh` starts
  intake and ends with STATE.json set to SPEC_READY.
- AC5: Running `python3 scripts/monitor_server.py` serves a local dashboard
  showing state, tasks, and log tail for projects.

## Notes
- The root repo remains a template and can host multiple projects in projects/.
