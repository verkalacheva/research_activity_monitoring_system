"""Unit tests for health_http.py."""
from __future__ import annotations

import io
import threading
import time
from http.client import HTTPConnection
from unittest.mock import AsyncMock, patch

import pytest

import health_http
from health_http import _Handler, start_background


# ---------------------------------------------------------------------------
# _Handler.do_GET via raw socket
# ---------------------------------------------------------------------------

def _make_handler_request(path: str, mock_ping: bool = True) -> tuple[int, bytes]:
    """
    Spin up a test server on a random port, send a single GET request,
    and return (status_code, body).
    """
    import socketserver

    class TestingHandler(_Handler):
        pass

    with socketserver.TCPServer(("127.0.0.1", 0), TestingHandler) as server:
        port = server.server_address[1]
        t = threading.Thread(target=server.handle_request)
        t.daemon = True
        t.start()

        conn = HTTPConnection("127.0.0.1", port)
        conn.request("GET", path)
        resp = conn.getresponse()
        body = resp.read()
        conn.close()
        t.join(timeout=2)
        return resp.status, body


class TestHandlerLiveEndpoint:
    def test_live_returns_200(self):
        status, _ = _make_handler_request("/health/live")
        assert status == 200

    def test_live_with_trailing_slash(self):
        status, _ = _make_handler_request("/health/live/")
        assert status == 200

    def test_live_with_query_params(self):
        status, _ = _make_handler_request("/health/live?foo=bar")
        assert status == 200


class TestHandlerReadyEndpoint:
    def test_ready_returns_200_when_db_ok(self):
        with patch("health_http.DbClient") as MockDbClient:
            instance = MockDbClient.return_value
            instance.ping = AsyncMock(return_value=True)
            status, _ = _make_handler_request("/health/ready")
        assert status == 200

    def test_ready_returns_503_when_db_fails(self):
        with patch("health_http.DbClient") as MockDbClient:
            instance = MockDbClient.return_value
            instance.ping = AsyncMock(return_value=False)
            status, body = _make_handler_request("/health/ready")
        assert status == 503
        assert b"database unavailable" in body


class TestHandlerUnknownPath:
    def test_unknown_path_returns_404(self):
        status, _ = _make_handler_request("/unknown")
        assert status == 404

    def test_root_path_returns_404(self):
        status, _ = _make_handler_request("/")
        assert status == 404


class TestRunAsync:
    def test_run_async_runs_coroutine(self):
        import asyncio

        async def sample():
            return 42

        result = health_http._run_async(sample())
        assert result == 42


class TestStartBackground:
    def test_returns_server(self, monkeypatch):
        monkeypatch.setenv("HEALTH_HTTP_PORT", "0")
        # Override to use an available port
        import socketserver

        original_init = socketserver.TCPServer.__init__

        server = start_background()
        assert server is not None
        server.shutdown()
