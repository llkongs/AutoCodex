# Start Here / 必读

If you only read one file, read this.

1) From the repo root, create a new project folder:
   bash scripts/init_project.sh my-project
2) Enter the new project folder:
   cd projects/my-project
3) Run intake and answer questions:
   bash scripts/tick.sh
4) Review ROLES.md and SPEC.md, then adjust if needed.
5) Set STATE.json to SPEC_READY or DEV_READY.
6) Run the worker loop:
   bash scripts/tick.sh

Rules
- Always work inside projects/<project-name>.
- Do not run init_project.sh inside projects/.
- Do not manually copy this repo; use the init script.
- The repo root contains TEMPLATE_ROOT, so tick.sh will refuse to run there.
