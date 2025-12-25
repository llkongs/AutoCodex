# AI Auto Task Frame

You are running inside a reusable automation framework.

Rules
- Read SPEC.md, TASKS.yaml, and STATE.json before making changes.
- Read ROLES.md and follow the role definitions for the project.
- Obey TASKS.yaml DoD and verification instructions.
- Keep changes minimal and aligned to SPEC.md.
- Update TASKS.yaml status as you complete items.
- Update STATE.json state when your role finishes.
- Do not set STATE.json to RUNNING; scripts/tick.sh handles that.
- If you are the diagnostician, write STATE.json.diagnosis and set diagnosis_done=true.
- If you are in the repo root, initialize a project under projects/ and work inside it.

Roles
- PO role: refine tasks and acceptance criteria only. Do not implement product code.
- DEV role: implement tasks, run verification, update task status and state.

State flow
INTAKE_READY -> SPEC_READY -> DEV_READY -> REVIEW_READY or SPEC_READY
DONE ends the loop. ERROR requires manual intervention.
