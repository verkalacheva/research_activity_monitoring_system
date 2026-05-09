"""Unit tests for infrastructure/crawl_cache.py."""
from __future__ import annotations

import json
import os
import time
import pytest

from infrastructure.crawl_cache import (
    _global_cache_off,
    _cache_root,
    _ttl_sec,
    _page_cache_enabled,
    _llm_cache_enabled,
    _embedding_cache_enabled,
    _key_hash,
    _path_for,
    _read_json,
    _write_json,
    cache_get_text,
    cache_set_text,
    cache_get_embedding,
    cache_set_embedding,
    llm_cache_key_material,
)


# ---------------------------------------------------------------------------
# _global_cache_off
# ---------------------------------------------------------------------------
class TestGlobalCacheOff:
    def test_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        assert _global_cache_off() is False

    def test_disabled_by_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")
        assert _global_cache_off() is True

    def test_disabled_by_false(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "false")
        assert _global_cache_off() is True

    def test_disabled_by_no(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "no")
        assert _global_cache_off() is True

    def test_disabled_by_off(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "off")
        assert _global_cache_off() is True

    def test_enabled_by_one(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "1")
        assert _global_cache_off() is False

    def test_enabled_by_yes(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "yes")
        assert _global_cache_off() is False


# ---------------------------------------------------------------------------
# _ttl_sec
# ---------------------------------------------------------------------------
class TestTtlSec:
    def test_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_TTL_SEC", raising=False)
        assert _ttl_sec() == 604800.0

    def test_custom(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")
        assert _ttl_sec() == 3600.0

    def test_invalid_falls_back_to_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "bad")
        assert _ttl_sec() == 604800.0

    def test_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "0")
        assert _ttl_sec() == 0.0

    def test_negative_clamped_to_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "-100")
        assert _ttl_sec() == 0.0


# ---------------------------------------------------------------------------
# _page_cache_enabled
# ---------------------------------------------------------------------------
class TestPageCacheEnabled:
    def test_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_PAGE_CACHE_ENABLED", raising=False)
        assert _page_cache_enabled() is True

    def test_disabled_when_global_off(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")
        assert _page_cache_enabled() is False

    def test_disabled_explicitly(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_PAGE_CACHE_ENABLED", "0")
        assert _page_cache_enabled() is False


# ---------------------------------------------------------------------------
# _llm_cache_enabled
# ---------------------------------------------------------------------------
class TestLlmCacheEnabled:
    def test_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_LLM_CACHE_ENABLED", raising=False)
        assert _llm_cache_enabled() is False

    def test_enabled_explicitly(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_LLM_CACHE_ENABLED", "1")
        assert _llm_cache_enabled() is True

    def test_disabled_when_global_off(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")
        monkeypatch.setenv("CRAWL_LLM_CACHE_ENABLED", "1")
        assert _llm_cache_enabled() is False


# ---------------------------------------------------------------------------
# _embedding_cache_enabled
# ---------------------------------------------------------------------------
class TestEmbeddingCacheEnabled:
    def test_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_EMBEDDING_CACHE_ENABLED", raising=False)
        assert _embedding_cache_enabled() is True

    def test_disabled_explicitly(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_EMBEDDING_CACHE_ENABLED", "0")
        assert _embedding_cache_enabled() is False

    def test_disabled_when_global_off(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")
        assert _embedding_cache_enabled() is False


# ---------------------------------------------------------------------------
# _key_hash
# ---------------------------------------------------------------------------
class TestKeyHash:
    def test_deterministic(self):
        h1 = _key_hash("ns", "key")
        h2 = _key_hash("ns", "key")
        assert h1 == h2

    def test_different_namespace(self):
        h1 = _key_hash("ns1", "key")
        h2 = _key_hash("ns2", "key")
        assert h1 != h2

    def test_different_material(self):
        h1 = _key_hash("ns", "key1")
        h2 = _key_hash("ns", "key2")
        assert h1 != h2

    def test_returns_hex_string(self):
        h = _key_hash("ns", "key")
        assert len(h) == 64
        int(h, 16)  # should not raise


# ---------------------------------------------------------------------------
# _cache_root
# ---------------------------------------------------------------------------
class TestCacheRoot:
    def test_custom_dir(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path / "custom_cache"))
        root = _cache_root()
        assert root == str(tmp_path / "custom_cache")
        assert os.path.isdir(root)

    def test_default_dir_created(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CACHE_DIR", raising=False)
        root = _cache_root()
        assert os.path.isdir(root)


# ---------------------------------------------------------------------------
# _read_json / _write_json
# ---------------------------------------------------------------------------
class TestReadWriteJson:
    def test_write_and_read(self, tmp_path):
        path = str(tmp_path / "test.json")
        data = {"ts": 1000.0, "v": "hello"}
        _write_json(path, data)
        result = _read_json(path)
        assert result == data

    def test_read_missing_file(self, tmp_path):
        result = _read_json(str(tmp_path / "missing.json"))
        assert result is None

    def test_read_invalid_json(self, tmp_path):
        path = str(tmp_path / "bad.json")
        with open(path, "w") as f:
            f.write("not json")
        result = _read_json(path)
        assert result is None


# ---------------------------------------------------------------------------
# _path_for
# ---------------------------------------------------------------------------
class TestPathFor:
    def test_creates_subdirectory(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        kh = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
        path = _path_for("myns", kh)
        expected_dir = os.path.join(str(tmp_path), "myns", kh[:2])
        assert os.path.isdir(expected_dir)
        assert path.endswith(f"{kh}.json")


# ---------------------------------------------------------------------------
# cache_get_text / cache_set_text
# ---------------------------------------------------------------------------
class TestCacheTextRoundTrip:
    def test_set_then_get(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_PAGE_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_text("page_text", "http://example.com", "Hello World")
        result = cache_get_text("page_text", "http://example.com")
        assert result == "Hello World"

    def test_get_missing_returns_none(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        result = cache_get_text("page_text", "http://not-cached.com")
        assert result is None

    def test_get_returns_none_when_global_off(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")

        result = cache_get_text("page_text", "key")
        assert result is None

    def test_set_no_op_when_global_off(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.setenv("CRAWL_CACHE_ENABLED", "0")
        # Should not raise
        cache_set_text("page_text", "key", "value")

    def test_expired_entry_returns_none(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_text("page_text", "old-url", "stale data")

        # Now set TTL to 0 to simulate expiry
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "0")
        result = cache_get_text("page_text", "old-url")
        assert result is None

    def test_llm_namespace_requires_enabled(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_LLM_CACHE_ENABLED", raising=False)  # default off
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_text("llm_json", "key", "value")
        result = cache_get_text("llm_json", "key")
        assert result is None

    def test_llm_namespace_works_when_enabled(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_LLM_CACHE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_text("llm_json", "key", "cached_llm")
        result = cache_get_text("llm_json", "key")
        assert result == "cached_llm"

    def test_llm_empty_namespace(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_LLM_CACHE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_text("llm_empty", "key", "")
        result = cache_get_text("llm_empty", "key")
        assert result == ""


# ---------------------------------------------------------------------------
# cache_get_embedding / cache_set_embedding
# ---------------------------------------------------------------------------
class TestCacheEmbeddingRoundTrip:
    def test_set_then_get(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.delenv("CRAWL_EMBEDDING_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        vector = [0.1, 0.2, 0.3]
        cache_set_embedding("model-v1", "text chunk", vector)
        result = cache_get_embedding("model-v1", "text chunk")
        assert result is not None
        assert len(result) == 3
        assert abs(result[0] - 0.1) < 1e-6

    def test_get_missing_returns_none(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        result = cache_get_embedding("model-v1", "not cached")
        assert result is None

    def test_get_returns_none_when_disabled(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.setenv("CRAWL_EMBEDDING_CACHE_ENABLED", "0")

        result = cache_get_embedding("model", "text")
        assert result is None

    def test_set_no_op_when_disabled(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.setenv("CRAWL_EMBEDDING_CACHE_ENABLED", "0")
        cache_set_embedding("model", "text", [1.0, 2.0])

    def test_expired_embedding_returns_none(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_embedding("model", "text", [1.0, 2.0, 3.0])

        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "0")
        result = cache_get_embedding("model", "text")
        assert result is None

    def test_different_models_different_entries(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        cache_set_embedding("model-a", "same text", [1.0])
        cache_set_embedding("model-b", "same text", [9.0])

        ra = cache_get_embedding("model-a", "same text")
        rb = cache_get_embedding("model-b", "same text")
        assert ra[0] == pytest.approx(1.0)
        assert rb[0] == pytest.approx(9.0)


# ---------------------------------------------------------------------------
# llm_cache_key_material
# ---------------------------------------------------------------------------
class TestLlmCacheKeyMaterial:
    def test_basic(self):
        key = llm_cache_key_material("http://x.com", "instr", "fp")
        assert "http://x.com" in key
        assert "instr" in key
        assert "fp" in key

    def test_with_retrieval_queries(self):
        key1 = llm_cache_key_material("url", "i", "fp", retrieval_queries=["q1", "q2"])
        key2 = llm_cache_key_material("url", "i", "fp", retrieval_queries=["q1"])
        assert key1 != key2

    def test_with_json_contract(self):
        key1 = llm_cache_key_material("url", "i", "fp", json_contract='{"a": 1}')
        key2 = llm_cache_key_material("url", "i", "fp", json_contract="")
        assert key1 != key2

    def test_with_completion_model(self):
        key1 = llm_cache_key_material("url", "i", "fp", completion_model="gpt-4")
        key2 = llm_cache_key_material("url", "i", "fp", completion_model="gpt-3.5")
        assert key1 != key2

    def test_deterministic(self):
        args = ("url", "instr", "fp")
        assert llm_cache_key_material(*args) == llm_cache_key_material(*args)

    def test_no_queries_produces_empty_hash_segment(self):
        key = llm_cache_key_material("url", "i", "fp")
        # Should have 5 separator characters (6 parts)
        assert key.count("\0") == 5
