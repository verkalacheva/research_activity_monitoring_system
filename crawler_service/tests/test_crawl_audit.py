"""Unit tests for infrastructure/crawl_audit.py."""
from __future__ import annotations

import json
import os
import tempfile

import pytest
from infrastructure.crawl_audit import append_audit


class TestAppendAudit:
    def test_does_nothing_when_no_path_set(self, monkeypatch):
        monkeypatch.delenv("CRAWL_AUDIT_LOG", raising=False)
        # Should not raise
        append_audit({"event": "test", "url": "https://example.com"})

    def test_does_nothing_when_empty_path(self, monkeypatch):
        monkeypatch.setenv("CRAWL_AUDIT_LOG", "")
        append_audit({"event": "test"})

    def test_writes_json_line_to_file(self, monkeypatch, tmp_path):
        log_file = tmp_path / "audit.jsonl"
        monkeypatch.setenv("CRAWL_AUDIT_LOG", str(log_file))

        append_audit({"event": "crawl_start", "url": "https://example.com"})

        assert log_file.exists()
        lines = log_file.read_text().strip().split("\n")
        assert len(lines) == 1
        data = json.loads(lines[0])
        assert data["event"] == "crawl_start"
        assert data["url"] == "https://example.com"
        assert "ts" in data

    def test_appends_multiple_entries(self, monkeypatch, tmp_path):
        log_file = tmp_path / "audit.jsonl"
        monkeypatch.setenv("CRAWL_AUDIT_LOG", str(log_file))

        append_audit({"event": "first"})
        append_audit({"event": "second"})
        append_audit({"event": "third"})

        lines = log_file.read_text().strip().split("\n")
        assert len(lines) == 3
        events = [json.loads(l)["event"] for l in lines]
        assert events == ["first", "second", "third"]

    def test_ts_field_is_iso_format(self, monkeypatch, tmp_path):
        log_file = tmp_path / "audit.jsonl"
        monkeypatch.setenv("CRAWL_AUDIT_LOG", str(log_file))

        append_audit({"event": "test"})

        data = json.loads(log_file.read_text())
        ts = data["ts"]
        assert "T" in ts  # ISO 8601 format includes 'T'
        assert "Z" in ts or "+" in ts  # timezone info

    def test_handles_ioerror_gracefully(self, monkeypatch, tmp_path):
        # Set a path to a non-existent directory
        monkeypatch.setenv("CRAWL_AUDIT_LOG", "/nonexistent/dir/audit.jsonl")
        # Should not raise an exception
        append_audit({"event": "should_not_crash"})

    def test_entry_contains_all_provided_fields(self, monkeypatch, tmp_path):
        log_file = tmp_path / "audit.jsonl"
        monkeypatch.setenv("CRAWL_AUDIT_LOG", str(log_file))

        append_audit({
            "event": "extraction",
            "url": "https://scholar.google.com/test",
            "researcher_id": 42,
            "achievement_count": 5,
        })

        data = json.loads(log_file.read_text())
        assert data["event"] == "extraction"
        assert data["researcher_id"] == 42
        assert data["achievement_count"] == 5
