# Spec

## Goal
Provide an initialization workflow so users can clone this framework repo and
create isolated project folders without manual copying.

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

## Acceptance Criteria
- AC1: Running `bash scripts/init_project.sh` creates a new folder under
  projects/ with the expected files and directories.
- AC2: Running `bash scripts/init_project.sh myproj` creates projects/myproj,
  or projects/myproj-2 if it already exists.
- AC3: The created project folder can run `bash scripts/tick.sh` without
  tripping the template guard.

## Notes
- The root repo remains a template and can host multiple projects in projects/.
