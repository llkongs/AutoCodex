#!/usr/bin/env python3
import json
import os
import re
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
                        self._json({"file": None, "tail": tail, "lines": []})
                        return
                    latest = logs[-1]
                    self._json({"file": latest.name, "tail": tail, "lines": tail_lines(latest, tail)})
                    return
                if len(parts) == 4 and parts[3] == "events":
                    query = parse_qs(url.query)
                    tail = int(query.get("tail", ["50"])[0])
                    events = read_events(project / "logs" / "events.ndjson", tail)
                    self._json({"tail": tail, "events": events})
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
