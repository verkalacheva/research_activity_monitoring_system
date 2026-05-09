"""Unit tests for infrastructure/crawl_offline_index.py."""
from __future__ import annotations

import json
import pytest
from unittest.mock import MagicMock, patch

from infrastructure.crawl_offline_index import (
    _enabled,
    _redis_url,
    _redis_key_prefix,
    _url_fingerprint,
    _snapshot_payload,
    record_page_snapshot,
    fetch_preview,
)


# ---------------------------------------------------------------------------
# _enabled
# ---------------------------------------------------------------------------
class TestEnabled:
    def test_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_OFFLINE_INDEX_ENABLED", raising=False)
        assert _enabled() is False

    def test_enabled_by_one(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        assert _enabled() is True

    def test_enabled_by_true(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "true")
        assert _enabled() is True

    def test_enabled_by_yes(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "yes")
        assert _enabled() is True

    def test_disabled_by_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "0")
        assert _enabled() is False

    def test_disabled_by_false(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "false")
        assert _enabled() is False


# ---------------------------------------------------------------------------
# _redis_url
# ---------------------------------------------------------------------------
class TestRedisUrl:
    def test_returns_empty_when_unset(self, monkeypatch):
        monkeypatch.delenv("CRAWL_REDIS_URL", raising=False)
        monkeypatch.delenv("REDIS_URL", raising=False)
        assert _redis_url() == ""

    def test_returns_crawl_redis_url(self, monkeypatch):
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")
        result = _redis_url()
        assert "redis" in result

    def test_falls_back_to_redis_url(self, monkeypatch):
        monkeypatch.delenv("CRAWL_REDIS_URL", raising=False)
        monkeypatch.setenv("REDIS_URL", "redis://fallback:6379")
        result = _redis_url()
        assert "fallback" in result


# ---------------------------------------------------------------------------
# _redis_key_prefix
# ---------------------------------------------------------------------------
class TestRedisKeyPrefix:
    def test_default_prefix(self, monkeypatch):
        monkeypatch.delenv("CRAWL_REDIS_KEY_PREFIX", raising=False)
        assert _redis_key_prefix() == "crawl:offline"

    def test_custom_prefix(self, monkeypatch):
        monkeypatch.setenv("CRAWL_REDIS_KEY_PREFIX", "myapp:crawl")
        assert _redis_key_prefix() == "myapp:crawl"

    def test_trailing_colon_stripped(self, monkeypatch):
        monkeypatch.setenv("CRAWL_REDIS_KEY_PREFIX", "myprefix:")
        assert _redis_key_prefix() == "myprefix"


# ---------------------------------------------------------------------------
# _url_fingerprint
# ---------------------------------------------------------------------------
class TestUrlFingerprint:
    def test_returns_sha256_hex(self):
        fp = _url_fingerprint("https://example.com")
        assert len(fp) == 64
        int(fp, 16)  # should not raise

    def test_deterministic(self):
        fp1 = _url_fingerprint("https://example.com")
        fp2 = _url_fingerprint("https://example.com")
        assert fp1 == fp2

    def test_different_urls_different_fingerprints(self):
        fp1 = _url_fingerprint("https://example.com")
        fp2 = _url_fingerprint("https://other.com")
        assert fp1 != fp2

    def test_strips_whitespace(self):
        fp1 = _url_fingerprint("  https://example.com  ")
        fp2 = _url_fingerprint("https://example.com")
        assert fp1 == fp2


# ---------------------------------------------------------------------------
# _snapshot_payload
# ---------------------------------------------------------------------------
class TestSnapshotPayload:
    def test_non_http_url_returns_none(self):
        assert _snapshot_payload("ftp://example.com", "text") is None

    def test_relative_url_returns_none(self):
        assert _snapshot_payload("relative/path", "text") is None

    def test_returns_valid_payload(self):
        payload = _snapshot_payload("https://example.com", "Hello World")
        assert payload is not None
        assert payload["url"] == "https://example.com"
        assert "content_sha256" in payload
        assert "text_len" in payload
        assert "ts" in payload
        assert "preview" in payload
        assert payload["text_len"] == 11

    def test_preview_truncated_at_2000(self):
        long_text = "x" * 5000
        payload = _snapshot_payload("https://example.com", long_text)
        assert len(payload["preview"]) == 2000

    def test_null_bytes_removed_from_preview(self):
        text_with_null = "hello\x00world"
        payload = _snapshot_payload("https://example.com", text_with_null)
        assert "\x00" not in payload["preview"]


# ---------------------------------------------------------------------------
# record_page_snapshot
# ---------------------------------------------------------------------------
class TestRecordPageSnapshot:
    def test_no_op_when_disabled(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "0")
        # Should not raise
        record_page_snapshot("https://example.com", "text")

    def test_no_op_when_empty_url(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        record_page_snapshot("", "text")

    def test_no_op_when_empty_text(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        record_page_snapshot("https://example.com", "")

    def test_logs_when_no_redis_url(self, monkeypatch, capsys):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.delenv("CRAWL_REDIS_URL", raising=False)
        monkeypatch.delenv("REDIS_URL", raising=False)
        record_page_snapshot("https://example.com", "some text")
        captured = capsys.readouterr()
        assert "REDIS_URL" in captured.out or "redis" in captured.out.lower()

    def test_sets_key_in_redis(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        mock_redis_client = MagicMock()
        mock_redis_module = MagicMock()
        mock_redis_module.from_url.return_value = mock_redis_client

        with patch.dict("sys.modules", {"redis": mock_redis_module}):
            record_page_snapshot("https://example.com", "some text content")

        mock_redis_client.set.assert_called_once()

    def test_handles_redis_exception_gracefully(self, monkeypatch, capsys):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        mock_redis_client = MagicMock()
        mock_redis_client.set.side_effect = Exception("connection refused")
        mock_redis_module = MagicMock()
        mock_redis_module.from_url.return_value = mock_redis_client

        with patch.dict("sys.modules", {"redis": mock_redis_module}):
            record_page_snapshot("https://example.com", "some text")

        captured = capsys.readouterr()
        assert "Redis" in captured.out or "redis" in captured.out.lower() or "connection" in captured.out.lower()

    def test_handles_import_error(self, monkeypatch, capsys):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        with patch.dict("sys.modules", {"redis": None}):
            # Should handle ImportError gracefully
            record_page_snapshot("https://example.com", "some text")


# ---------------------------------------------------------------------------
# fetch_preview
# ---------------------------------------------------------------------------
class TestFetchPreview:
    def test_returns_none_when_disabled(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "0")
        assert fetch_preview("https://example.com") is None

    def test_returns_none_when_no_redis_url(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.delenv("CRAWL_REDIS_URL", raising=False)
        monkeypatch.delenv("REDIS_URL", raising=False)
        assert fetch_preview("https://example.com") is None

    def test_returns_preview_from_redis(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        payload = {"url": "https://example.com", "preview": "Cached preview text"}
        mock_redis_client = MagicMock()
        mock_redis_client.get.return_value = json.dumps(payload)
        mock_redis_module = MagicMock()
        mock_redis_module.from_url.return_value = mock_redis_client

        with patch.dict("sys.modules", {"redis": mock_redis_module}):
            result = fetch_preview("https://example.com")

        assert result == "Cached preview text"

    def test_returns_none_when_key_not_found(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        mock_redis_client = MagicMock()
        mock_redis_client.get.return_value = None
        mock_redis_module = MagicMock()
        mock_redis_module.from_url.return_value = mock_redis_client

        with patch.dict("sys.modules", {"redis": mock_redis_module}):
            result = fetch_preview("https://example.com")

        assert result is None

    def test_handles_redis_exception(self, monkeypatch):
        monkeypatch.setenv("CRAWL_OFFLINE_INDEX_ENABLED", "1")
        monkeypatch.setenv("CRAWL_REDIS_URL", "redis://localhost:6379")

        mock_redis_client = MagicMock()
        mock_redis_client.get.side_effect = Exception("timeout")
        mock_redis_module = MagicMock()
        mock_redis_module.from_url.return_value = mock_redis_client

        with patch.dict("sys.modules", {"redis": mock_redis_module}):
            result = fetch_preview("https://example.com")

        assert result is None
