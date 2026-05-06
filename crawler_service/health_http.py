"""Lightweight HTTP /health/live and /health/ready (separate from gRPC port)."""
import asyncio
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from infrastructure.db_client import DbClient


def _run_async(coro):
    return asyncio.run(coro)


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path == "/health/live":
            self.send_response(200)
            self.end_headers()
            return
        if path == "/health/ready":
            ok = _run_async(DbClient().ping())
            if ok:
                self.send_response(200)
                self.end_headers()
            else:
                self.send_response(503)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.end_headers()
                self.wfile.write(b"database unavailable\n")
            return
        self.send_response(404)
        self.end_headers()


def start_background():
    port = int(os.getenv("HEALTH_HTTP_PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), _Handler)
    server.daemon_threads = True
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server
