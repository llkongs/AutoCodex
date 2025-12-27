#!/usr/bin/env python3
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


BASE_DIR = Path(__file__).resolve().parents[1]
PROJECTS_DIR = BASE_DIR / "projects"
DASHBOARD_DIR = BASE_DIR / "dashboard"


def safe_project_path(name):
    if not name or "/" in name or "\\" in name or name.startswith("."):
        return None
    path = PROJECTS_DIR / name
    if not path.exists() or not path.is_dir():
        return None
    return path


def safe_review_file(project, relpath):
    if not relpath or relpath.startswith("/") or relpath.startswith("."):
        return None
    if ".." in relpath or "\\" in relpath:
        return None
    if not relpath.endswith(".md"):
        return None
    allowed = ("notes/", "drafts/", "chapters/")
    if not any(relpath.startswith(prefix) for prefix in allowed):
        return None
    full = (project / relpath).resolve()
    if not str(full).startswith(str(project.resolve())):
        return None
    if not full.exists() or not full.is_file():
        return None
    return full


def read_json(path):
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}


def tail_lines(path, count):
    try:
        lines = path.read_text().splitlines()
    except Exception:
        return []
    if count <= 0:
        return []
    return lines[-count:]


def write_state(path, updates):
    data = read_json(path) if path.exists() else {}
    data.update(updates)
    path.write_text(json.dumps(data, indent=2))


def start_auto_run(project):
    state_path = project / "STATE.json"
    state = read_json(state_path)
    if state.get("auto_run_pid"):
        return
    tick_path = BASE_DIR / "scripts" / "tick.sh"
    cmd = [
        "bash",
        "-lc",
        f"while true; do bash '{tick_path}' --project '{project}'; sleep 20; done",
    ]
    proc = subprocess.Popen(cmd, cwd=str(BASE_DIR), start_new_session=True)
    write_state(state_path, {"auto_run": True, "auto_run_pid": proc.pid})


def stop_auto_run(project):
    state_path = project / "STATE.json"
    state = read_json(state_path)
    pid = state.get("auto_run_pid")
    if pid:
        try:
            os.killpg(pid, 15)
        except Exception:
            pass
    write_state(state_path, {"auto_run": False, "auto_run_pid": None})


def read_events(path, count):
    if not path.exists():
        return []
    lines = tail_lines(path, count)
    events = []
    for line in lines:
        try:
            events.append(json.loads(line))
        except Exception:
            continue
    return events


def parse_tasks(path):
    if not path.exists():
        return {"total": 0, "done": 0, "items": []}
    items = []
    current = {}
    for line in path.read_text().splitlines():
        if re.match(r"^\s*-\s+id:\s*", line):
            if current:
                items.append(current)
            current = {"id": line.split("id:", 1)[1].strip(), "title": "", "status": ""}
        elif re.match(r"^\s*title:\s*", line):
            current["title"] = line.split("title:", 1)[1].strip().strip('"')
        elif re.match(r"^\s*status:\s*", line):
            current["status"] = line.split("status:", 1)[1].strip().split()[0]
    if current:
        items.append(current)
    total = len(items)
    done = len([i for i in items if i.get("status") == "done"])
    return {"total": total, "done": done, "items": items}


class Handler(BaseHTTPRequestHandler):
    def _json(self, payload, status=200):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _text(self, text, status=200, content_type="text/plain; charset=utf-8"):
        data = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _serve_static(self, path):
        if not path.exists():
            self._text("Not found", status=404)
            return
        content_type = "text/plain; charset=utf-8"
        if path.suffix == ".html":
            content_type = "text/html; charset=utf-8"
        elif path.suffix == ".css":
            content_type = "text/css; charset=utf-8"
        elif path.suffix == ".js":
            content_type = "application/javascript; charset=utf-8"
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path

        if path == "/" or path == "/index.html":
            self._serve_static(DASHBOARD_DIR / "index.html")
            return

        if path.startswith("/api/projects"):
            parts = path.strip("/").split("/")
            if len(parts) == 2:
                projects = []
                if PROJECTS_DIR.exists():
                    for p in sorted(PROJECTS_DIR.iterdir()):
                        if p.is_dir() and not p.name.startswith("."):
                            projects.append(p.name)
                self._json({"projects": projects})
                return

            if len(parts) >= 3:
                name = parts[2]
                project = safe_project_path(name)
                if not project:
                    self._json({"error": "project not found"}, status=404)
                    return

                if len(parts) == 4 and parts[3] == "state":
                    self._json(read_json(project / "STATE.json"))
                    return
                if len(parts) == 4 and parts[3] == "tasks":
                    self._json(parse_tasks(project / "TASKS.yaml"))
                    return
                if len(parts) == 4 and parts[3] == "logs":
                    query = parse_qs(url.query)
                    tail = int(query.get("tail", ["200"])[0])
                    logs = sorted((project / "logs").glob("*.log"), key=os.path.getmtime)
                    if not logs:
                        self._json({"file": None, "tail": tail, "lines": [], "mtime": None, "size": None})
                        return
                    latest = logs[-1]
                    stat = latest.stat()
                    self._json(
                        {
                            "file": latest.name,
                            "tail": tail,
                            "lines": tail_lines(latest, tail),
                            "mtime": int(stat.st_mtime),
                            "size": stat.st_size,
                        }
                    )
                    return
                if len(parts) == 4 and parts[3] == "events":
                    query = parse_qs(url.query)
                    tail = int(query.get("tail", ["50"])[0])
                    events = read_events(project / "logs" / "events.ndjson", tail)
                    self._json({"tail": tail, "events": events})
                    return
                if len(parts) == 4 and parts[3] == "intake":
                    questions = ""
                    answers = ""
                    q_path = project / "INTAKE_QUESTIONS.md"
                    a_path = project / "INTAKE_ANSWERS.md"
                    if q_path.exists():
                        questions = q_path.read_text()
                    if a_path.exists():
                        answers = a_path.read_text()
                    self._json({"questions": questions, "answers": answers})
                    return
                if len(parts) == 4 and parts[3] == "interaction":
                    notes_path = project / "notes" / "interaction_notes.md"
                    notes_path.parent.mkdir(parents=True, exist_ok=True)
                    notes = notes_path.read_text() if notes_path.exists() else ""
                    state = read_json(project / "STATE.json")
                    self._json(
                        {
                            "notes": notes,
                            "interactive_mode": bool(state.get("interactive_mode", True)),
                            "state": state.get("state", ""),
                            "resume_state": state.get("resume_state", ""),
                        }
                    )
                    return
                if len(parts) == 4 and parts[3] == "review":
                    state = read_json(project / "STATE.json").get("state", "")
                    review_items = read_json(project / "STATE.json").get("review_items", [])
                    items = []
                    for folder in ("notes", "drafts", "chapters"):
                        base = project / folder
                        if base.exists() and base.is_dir():
                            for path in sorted(base.glob("*.md")):
                                items.append(f"{folder}/{path.name}")
                    if not review_items:
                        review_items = items
                    self._json({"state": state, "items": review_items})
                    return
                if len(parts) == 4 and parts[3] == "file":
                    query = parse_qs(url.query)
                    relpath = query.get("path", [""])[0]
                    file_path = safe_review_file(project, relpath)
                    if not file_path:
                        self._json({"error": "invalid path"}, status=400)
                        return
                    self._json({"path": relpath, "content": file_path.read_text()})
                    return

        self._text("Not found", status=404)

    def do_POST(self):
        url = urlparse(self.path)
        path = url.path
        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            payload = {}

        if path.startswith("/api/projects"):
            parts = path.strip("/").split("/")
            if len(parts) >= 3:
                name = parts[2]
                project = safe_project_path(name)
                if not project:
                    self._json({"error": "project not found"}, status=404)
                    return

                if len(parts) == 4 and parts[3] == "pause":
                    state_path = project / "STATE.json"
                    now = int(__import__("time").time())
                    write_state(
                        state_path,
                        {
                            "state": "PAUSED",
                            "role": None,
                            "run_id": None,
                            "started_at": None,
                            "updated_at": now,
                            "heartbeat_at": now,
                        },
                    )
                    self._json({"ok": True})
                    return

                if len(parts) == 4 and parts[3] == "resume":
                    state_path = project / "STATE.json"
                    now = int(__import__("time").time())
                    write_state(
                        state_path,
                        {
                            "state": "INTAKE_READY",
                            "role": None,
                            "run_id": None,
                            "started_at": None,
                            "updated_at": now,
                            "heartbeat_at": now,
                        },
                    )
                    self._json({"ok": True})
                    return

                if len(parts) == 4 and parts[3] == "intake":
                    answers = payload.get("answers", "")
                    (project / "INTAKE_ANSWERS.md").write_text(answers)
                    state_path = project / "STATE.json"
                    now = int(__import__("time").time())
                    write_state(
                        state_path,
                        {
                            "state": "INTAKE_READY",
                            "role": None,
                            "run_id": None,
                            "started_at": None,
                            "updated_at": now,
                            "heartbeat_at": now,
                        },
                    )
                    self._json({"ok": True})
                    return
                if len(parts) == 4 and parts[3] == "interaction":
                    notes = payload.get("notes", "")
                    notes_path = project / "notes" / "interaction_notes.md"
                    notes_path.parent.mkdir(parents=True, exist_ok=True)
                    notes_path.write_text(notes)
                    state_path = project / "STATE.json"
                    if "interactive_mode" in payload:
                        interactive = bool(payload["interactive_mode"])
                        state = read_json(state_path)
                        updates = {"interactive_mode": interactive}
                        if not interactive and state.get("state") in ("REVIEW_READY", "REVIEW_WAITING", "PAUSE_INTERACT"):
                            updates.update(
                                {
                                    "state": "DEV_READY",
                                    "resume_state": None,
                                    "role": None,
                                    "run_id": None,
                                    "started_at": None,
                                    "updated_at": int(__import__("time").time()),
                                    "heartbeat_at": int(__import__("time").time()),
                                }
                            )
                        write_state(state_path, updates)
                        if interactive:
                            stop_auto_run(project)
                        else:
                            start_auto_run(project)
                    self._json({"ok": True})
                    return
                if len(parts) == 5 and parts[3] == "interaction" and parts[4] == "pause":
                    state_path = project / "STATE.json"
                    state = read_json(state_path)
                    (project / "notes" / "interrupt.flag").write_text("pause")
                    if state.get("state") != "RUNNING":
                        now = int(__import__("time").time())
                        write_state(
                            state_path,
                            {
                                "state": "PAUSE_INTERACT",
                                "resume_state": state.get("state", "DEV_READY"),
                                "updated_at": now,
                                "heartbeat_at": now,
                            },
                        )
                    self._json({"ok": True})
                    return
                if len(parts) == 5 and parts[3] == "interaction" and parts[4] == "continue":
                    state_path = project / "STATE.json"
                    state = read_json(state_path)
                    resume = state.get("resume_state") or "DEV_READY"
                    now = int(__import__("time").time())
                    write_state(
                        state_path,
                        {
                            "state": resume,
                            "resume_state": None,
                            "role": None,
                            "run_id": None,
                            "started_at": None,
                            "updated_at": now,
                            "heartbeat_at": now,
                        },
                    )
                    flag = project / "notes" / "interrupt.flag"
                    if flag.exists():
                        flag.unlink()
                    self._json({"ok": True})
                    return
                if len(parts) == 5 and parts[3] == "review" and parts[4] == "continue":
                    state_path = project / "STATE.json"
                    now = int(__import__("time").time())
                    write_state(
                        state_path,
                        {
                            "state": "DEV_READY",
                            "role": None,
                            "run_id": None,
                            "started_at": None,
                            "updated_at": now,
                            "heartbeat_at": now,
                            "review_items": [],
                        },
                    )
                    self._json({"ok": True})
                    return
                if len(parts) == 4 and parts[3] == "run":
                    tick_path = BASE_DIR / "scripts" / "tick.sh"
                    subprocess.Popen(
                        ["bash", str(tick_path), "--project", str(project)],
                        cwd=str(BASE_DIR),
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    self._json({"ok": True})
                    return

        self._text("Not found", status=404)


def main():
    host = "127.0.0.1"
    port = int(os.environ.get("STATUS_PORT", "8787"))
    httpd = HTTPServer((host, port), Handler)
    print(f"Dashboard: http://{host}:{port}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
