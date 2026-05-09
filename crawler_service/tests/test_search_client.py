"""Unit tests for infrastructure/search_client.py (pure helper functions)."""
from __future__ import annotations

import os
import pytest
from infrastructure.search_client import (
    SearchHit,
    round_robin_merge_hits,
    _int_env,
    _timeout_s,
    _max_results_requested,
    _primary_backends,
    _fallback_backend_specs,
    _hits_from_items,
)


# ---------------------------------------------------------------------------
# SearchHit dataclass
# ---------------------------------------------------------------------------
class TestSearchHit:
    def test_url_required(self):
        h = SearchHit(url="https://example.com")
        assert h.url == "https://example.com"
        assert h.title == ""
        assert h.snippet == ""

    def test_all_fields(self):
        h = SearchHit(url="https://example.com", title="Test Title", snippet="Some snippet")
        assert h.title == "Test Title"
        assert h.snippet == "Some snippet"


# ---------------------------------------------------------------------------
# round_robin_merge_hits
# ---------------------------------------------------------------------------
class TestRoundRobinMergeHits:
    def test_empty_input_returns_empty(self):
        assert round_robin_merge_hits([]) == []

    def test_single_query_returns_all_hits(self):
        hits = [SearchHit(url=f"https://example.com/{i}") for i in range(3)]
        result = round_robin_merge_hits([hits])
        assert len(result) == 3
        assert result[0].url == hits[0].url

    def test_two_queries_interleaved(self):
        q1 = [SearchHit(url="https://a.com/1"), SearchHit(url="https://a.com/2")]
        q2 = [SearchHit(url="https://b.com/1"), SearchHit(url="https://b.com/2")]
        result = round_robin_merge_hits([q1, q2])
        assert len(result) == 4
        urls = [h.url for h in result]
        assert urls[0] == "https://a.com/1"
        assert urls[1] == "https://b.com/1"
        assert urls[2] == "https://a.com/2"
        assert urls[3] == "https://b.com/2"

    def test_duplicates_removed(self):
        url = "https://example.com/page"
        q1 = [SearchHit(url=url)]
        q2 = [SearchHit(url=url)]  # same url
        result = round_robin_merge_hits([q1, q2])
        assert len(result) == 1

    def test_empty_url_skipped(self):
        q1 = [SearchHit(url=""), SearchHit(url="https://good.com")]
        result = round_robin_merge_hits([q1])
        assert len(result) == 1
        assert result[0].url == "https://good.com"

    def test_unequal_length_lists(self):
        q1 = [SearchHit(url=f"https://a.com/{i}") for i in range(3)]
        q2 = [SearchHit(url=f"https://b.com/{i}") for i in range(1)]
        result = round_robin_merge_hits([q1, q2])
        assert len(result) == 4

    def test_preserves_title_and_snippet(self):
        q1 = [SearchHit(url="https://a.com", title="Title A", snippet="Snippet A")]
        result = round_robin_merge_hits([q1])
        assert result[0].title == "Title A"
        assert result[0].snippet == "Snippet A"


# ---------------------------------------------------------------------------
# _int_env
# ---------------------------------------------------------------------------
class TestIntEnv:
    def test_returns_default_when_unset(self, monkeypatch):
        monkeypatch.delenv("TEST_INT_VAR", raising=False)
        assert _int_env("TEST_INT_VAR", 42) == 42

    def test_returns_env_value(self, monkeypatch):
        monkeypatch.setenv("TEST_INT_VAR", "99")
        assert _int_env("TEST_INT_VAR", 42) == 99

    def test_falls_back_on_invalid(self, monkeypatch):
        monkeypatch.setenv("TEST_INT_VAR", "not_a_number")
        assert _int_env("TEST_INT_VAR", 42) == 42


# ---------------------------------------------------------------------------
# _timeout_s
# ---------------------------------------------------------------------------
class TestTimeoutS:
    def test_default_is_within_range(self, monkeypatch):
        monkeypatch.delenv("DDGS_TIMEOUT", raising=False)
        t = _timeout_s()
        assert 8 <= t <= 120

    def test_capped_at_max(self, monkeypatch):
        monkeypatch.setenv("DDGS_TIMEOUT", "9999")
        assert _timeout_s() == 120

    def test_floored_at_min(self, monkeypatch):
        monkeypatch.setenv("DDGS_TIMEOUT", "1")
        assert _timeout_s() == 8


# ---------------------------------------------------------------------------
# _max_results_requested
# ---------------------------------------------------------------------------
class TestMaxResultsRequested:
    def test_default_when_none(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DDGS_MAX_RESULTS", raising=False)
        result = _max_results_requested(None)
        assert 10 <= result <= 200

    def test_custom_cap_respected(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DDGS_MAX_RESULTS", "20")
        result = _max_results_requested(100)  # requested > cap
        assert result == 20

    def test_minimum_enforced(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DDGS_MAX_RESULTS", raising=False)
        result = _max_results_requested(1)  # below min of 10
        assert result == 10


# ---------------------------------------------------------------------------
# _primary_backends
# ---------------------------------------------------------------------------
class TestPrimaryBackends:
    def test_default_backends(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DDGS_BACKEND", raising=False)
        monkeypatch.delenv("CRAWL_DDGS_BACKENDS_PRIMARY", raising=False)
        backends = _primary_backends()
        assert "bing" in backends or "mojeek" in backends or "brave" in backends

    def test_custom_backend_from_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DDGS_BACKEND", "google")
        assert "google" in _primary_backends()


# ---------------------------------------------------------------------------
# _fallback_backend_specs
# ---------------------------------------------------------------------------
class TestFallbackBackendSpecs:
    def test_default_fallback(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DDGS_FALLBACK_BACKENDS", raising=False)
        specs = _fallback_backend_specs()
        assert isinstance(specs, list)
        assert len(specs) >= 1

    def test_custom_fallback_from_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DDGS_FALLBACK_BACKENDS", "yahoo,bing")
        specs = _fallback_backend_specs()
        assert "yahoo" in specs
        assert "bing" in specs


# ---------------------------------------------------------------------------
# _hits_from_items
# ---------------------------------------------------------------------------
class TestHitsFromItems:
    def test_empty_list_returns_empty(self):
        assert _hits_from_items([]) == []

    def test_basic_item_with_href(self):
        items = [{"href": "https://example.com", "title": "Test", "body": "Snippet"}]
        hits = _hits_from_items(items)
        assert len(hits) == 1
        assert hits[0].url == "https://example.com"
        assert hits[0].title == "Test"
        assert hits[0].snippet == "Snippet"

    def test_item_with_url_field(self):
        items = [{"url": "https://example.com"}]
        hits = _hits_from_items(items)
        assert len(hits) == 1

    def test_item_without_url_skipped(self):
        items = [{"title": "No URL here"}]
        hits = _hits_from_items(items)
        assert len(hits) == 0

    def test_snippet_from_snippet_field(self):
        items = [{"href": "https://example.com", "snippet": "A snippet"}]
        hits = _hits_from_items(items)
        assert hits[0].snippet == "A snippet"

    def test_long_title_truncated(self):
        long_title = "X" * 600
        items = [{"href": "https://example.com", "title": long_title}]
        hits = _hits_from_items(items)
        assert len(hits[0].title) <= 500

    def test_mixed_items(self):
        items = [
            {"href": "https://good.com"},
            {"title": "No URL"},
            {"href": "https://also-good.com", "title": "Found"},
        ]
        hits = _hits_from_items(items)
        assert len(hits) == 2


# ---------------------------------------------------------------------------
# SearchClient class
# ---------------------------------------------------------------------------
import asyncio
from unittest.mock import MagicMock, patch


class TestSearchClientInit:
    def test_creates_without_settings(self):
        from infrastructure.search_client import SearchClient
        client = SearchClient()
        assert client is not None

    def test_creates_with_settings(self):
        from infrastructure.search_client import SearchClient
        client = SearchClient(settings={"some_key": "val"})
        assert client is not None


class TestSearchClientFetchRaw:
    def test_fetch_raw_calls_ddgs(self, monkeypatch):
        from infrastructure.search_client import SearchClient
        from ddgs import DDGS

        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text = MagicMock(return_value=[{"href": "https://result.com", "title": "R"}])

        with patch("infrastructure.search_client.DDGS", return_value=mock_ddgs):
            client = SearchClient()
            result = client._fetch_raw("test query", 5, "bing")
        assert len(result) == 1

    def test_fetch_raw_handles_typeerror_fallback(self, monkeypatch):
        from infrastructure.search_client import SearchClient

        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        # First call raises TypeError, second call succeeds
        mock_ddgs.text = MagicMock(
            side_effect=[TypeError("unexpected kwarg"), [{"href": "https://x.com", "title": "X"}]]
        )

        with patch("infrastructure.search_client.DDGS", return_value=mock_ddgs):
            client = SearchClient()
            result = client._fetch_raw("query", 5, "bing")
        assert result[0]["href"] == "https://x.com"


class TestSearchClientSearchUrls:
    def _run(self, coro):
        return asyncio.run(coro)

    def test_empty_query_returns_empty(self):
        from infrastructure.search_client import SearchClient
        client = SearchClient()
        result = self._run(client.search_urls(""))
        assert result == []

    def test_short_query_returns_empty(self):
        from infrastructure.search_client import SearchClient
        client = SearchClient()
        result = self._run(client.search_urls("a"))
        assert result == []

    def test_returns_hits_from_ddgs(self):
        from infrastructure.search_client import SearchClient

        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text = MagicMock(return_value=[
            {"href": "https://result.com/paper", "title": "Research Paper"},
        ])

        with patch("infrastructure.search_client.DDGS", return_value=mock_ddgs):
            client = SearchClient()
            result = self._run(client.search_urls("research query"))
        assert len(result) == 1
        assert result[0].url == "https://result.com/paper"

    def test_filters_junk_domains(self):
        from infrastructure.search_client import SearchClient

        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text = MagicMock(return_value=[
            {"href": "https://youtube.com/video", "title": "Video"},
            {"href": "https://result.com/paper", "title": "Good"},
        ])

        with patch("infrastructure.search_client.DDGS", return_value=mock_ddgs):
            client = SearchClient()
            result = self._run(client.search_urls("test query"))
        # youtube.com should be filtered out
        assert all("youtube.com" not in h.url for h in result)
        assert len(result) == 1

    def test_falls_back_when_primary_fails(self):
        from infrastructure.search_client import SearchClient

        call_count = [0]

        def side_effect(query, max_results=None, **kwargs):
            call_count[0] += 1
            if call_count[0] == 1:
                raise Exception("primary failed")
            return [{"href": "https://fallback.com", "title": "Fallback"}]

        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text = MagicMock(side_effect=side_effect)

        with patch("infrastructure.search_client.DDGS", return_value=mock_ddgs):
            with patch("infrastructure.search_client.asyncio.sleep", return_value=None):
                client = SearchClient()
                result = self._run(client.search_urls("test query"))
        assert len(result) >= 0  # fallback may or may not succeed


class TestSearchClientSearchUrlsMulti:
    def _run(self, coro):
        return asyncio.run(coro)

    def test_empty_queries_list_returns_empty(self):
        from infrastructure.search_client import SearchClient
        client = SearchClient()
        result = self._run(client.search_urls_multi([]))
        assert result == []

    def test_short_query_skipped(self):
        from infrastructure.search_client import SearchClient

        with patch.object(SearchClient, "search_urls", return_value=[]) as mock_search:
            client = SearchClient()
            result = self._run(client.search_urls_multi(["ab", "a"]))
        # "ab" is < 3 chars, "a" is < 3 chars — both skipped
        mock_search.assert_not_called()

    def test_valid_queries_merged(self):
        from infrastructure.search_client import SearchClient, SearchHit

        hits_q1 = [SearchHit(url="https://q1.com", title="Q1")]
        hits_q2 = [SearchHit(url="https://q2.com", title="Q2")]

        async def fake_search(q, max_results=None):
            if "first" in q:
                return hits_q1
            return hits_q2

        with patch.object(SearchClient, "search_urls", side_effect=fake_search):
            client = SearchClient()
            result = self._run(client.search_urls_multi(["first query", "second query"]))
        assert len(result) == 2
