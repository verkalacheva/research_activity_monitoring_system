#!/usr/bin/env python3
"""Один HTTP-сервер для всех HTML-отчётов покрытия (backend, crawler, integration, analytics)."""

from __future__ import annotations

import argparse
import mimetypes
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# slug -> (каталог на диске, файл по умолчанию для /slug и /slug/)
MOUNTS: dict[str, tuple[Path, str]] = {
    "backend": (REPO_ROOT / "backend" / "coverage", "index.html"),
    "crawler": (REPO_ROOT / "crawler_service" / "coverage" / "html", "index.html"),
    "integration": (REPO_ROOT / "integration_service" / "coverage", "coverage.html"),
    "analytics": (REPO_ROOT / "analytics_service" / "coverage", "coverage.html"),
}


def _under_root(root: Path, candidate: Path) -> bool:
    try:
        candidate.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _resolve_mount(slug: str, rel: str) -> Path | None:
    if slug not in MOUNTS:
        return None
    root, default = MOUNTS[slug]
    if not root.is_dir():
        return None
    root = root.resolve()
    rel = rel.strip("/")
    if not rel:
        p = (root / default).resolve()
        return p if p.is_file() else None
    candidate = (root / rel).resolve()
    if not _under_root(root, candidate):
        return None
    if candidate.is_file():
        return candidate
    if candidate.is_dir():
        idx = (candidate / "index.html").resolve()
        if _under_root(root, idx) and idx.is_file():
            return idx
    return None


def _html_index(host: str) -> bytes:
    rows = []
    for slug, (root, default) in MOUNTS.items():
        url = f"http://{host}/{slug}/"
        exists = root.is_dir() and (root / default).is_file()
        status = "есть" if exists else "нет (запустите тесты с покрытием)"
        rows.append(
            f'<li><a href="/{slug}/">{slug}</a> — {root.relative_to(REPO_ROOT)} ({status})</li>'
        )
    summary = REPO_ROOT / "coverage_summary.txt"
    extra = ""
    if summary.is_file():
        extra = f'<p>Сводка: <a href="/coverage_summary.txt">coverage_summary.txt</a></p>'
    html = f"""<!DOCTYPE html>
<html lang="ru">
<head><meta charset="utf-8"><title>Coverage reports</title></head>
<body>
<h1>Отчёты покрытия</h1>
<ul>
{chr(10).join(rows)}
</ul>
{extra}
<p><small>Ctrl+C — остановить сервер</small></p>
</body>
</html>"""
    return html.encode("utf-8")


class CoverageHandler(BaseHTTPRequestHandler):
    server_version = "CoverageReports/1.0"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path)
        if path != "/" and path.endswith("/"):
            path = path[:-1]

        if path in ("", "/"):
            host = self.headers.get("Host", "127.0.0.1")
            body = _html_index(host)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if path == "/coverage_summary.txt":
            p = REPO_ROOT / "coverage_summary.txt"
            if not p.is_file():
                self.send_error(404)
                return
            body = p.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        path = path.lstrip("/")
        parts = path.split("/", 1)
        slug = parts[0]
        rel = parts[1] if len(parts) > 1 else ""
        fs = _resolve_mount(slug, rel)
        if fs is None:
            self.send_error(404)
            return
        ctype, _ = mimetypes.guess_type(fs.name)
        if ctype is None:
            ctype = "application/octet-stream"
        body = fs.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    ap = argparse.ArgumentParser(description="Serve all coverage HTML under one port.")
    ap.add_argument("--host", default="127.0.0.1", help="bind address (default 127.0.0.1)")
    ap.add_argument("--port", type=int, default=8765, help="port (default 8765)")
    args = ap.parse_args()
    httpd = ThreadingHTTPServer((args.host, args.port), CoverageHandler)
    print(f"Coverage reports: http://{args.host}:{args.port}/", flush=True)
    print("  backend       → /backend/", flush=True)
    print("  crawler       → /crawler/", flush=True)
    print("  integration   → /integration/", flush=True)
    print("  analytics     → /analytics/", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.", flush=True)


if __name__ == "__main__":
    main()
