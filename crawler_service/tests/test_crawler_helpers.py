"""Unit tests for pure helper functions in infrastructure/crawler_client.py."""
from __future__ import annotations

import pytest
import asyncio
from unittest.mock import patch, AsyncMock

import infrastructure.crawler_client as cc


# ---------------------------------------------------------------------------
# _require_llm_api_key
# ---------------------------------------------------------------------------
class TestRequireLlmApiKey:
    def test_valid_key_returned(self):
        result = cc._require_llm_api_key("sk-1234567890abcdef")
        assert result == "sk-1234567890abcdef"

    def test_empty_key_raises(self):
        with pytest.raises(ValueError, match="API-ключ"):
            cc._require_llm_api_key("")

    def test_whitespace_only_raises(self):
        with pytest.raises(ValueError):
            cc._require_llm_api_key("   ")

    def test_none_raises(self):
        with pytest.raises(ValueError):
            cc._require_llm_api_key(None)

    def test_comma_separated_returns_first(self):
        result = cc._require_llm_api_key("key1, key2, key3")
        assert result == "key1"

    def test_strips_whitespace(self):
        result = cc._require_llm_api_key("  my-api-key  ")
        assert result == "my-api-key"


# ---------------------------------------------------------------------------
# _llm_api_key_from_settings
# ---------------------------------------------------------------------------
class TestLlmApiKeyFromSettings:
    def test_key_from_settings(self):
        settings = {"llm_api_key": "sk-fromdb"}
        result = cc._llm_api_key_from_settings(settings)
        assert result == "sk-fromdb"

    def test_empty_settings_raises(self):
        with pytest.raises(ValueError):
            cc._llm_api_key_from_settings({})

    def test_none_settings_raises(self):
        with pytest.raises(ValueError):
            cc._llm_api_key_from_settings(None)

    def test_empty_key_in_settings_raises(self):
        with pytest.raises(ValueError):
            cc._llm_api_key_from_settings({"llm_api_key": ""})


# ---------------------------------------------------------------------------
# _llm_circuit_is_open
# ---------------------------------------------------------------------------
class TestLlmCircuitIsOpen:
    def test_initially_closed(self):
        # Reset state
        import infrastructure.crawler_client as module
        module._llm_circuit_open_until = 0.0
        assert cc._llm_circuit_is_open() is False

    def test_open_when_in_cooldown(self):
        import time
        import infrastructure.crawler_client as module
        module._llm_circuit_open_until = time.monotonic() + 1000.0
        assert cc._llm_circuit_is_open() is True
        module._llm_circuit_open_until = 0.0  # reset


# ---------------------------------------------------------------------------
# _llm_record_success
# ---------------------------------------------------------------------------
class TestLlmRecordSuccess:
    def test_resets_streak(self):
        import infrastructure.crawler_client as module
        module._llm_429_streak = 5
        cc._llm_record_success()
        assert module._llm_429_streak == 0


# ---------------------------------------------------------------------------
# _next_chunk_threshold_for_merge_bug
# ---------------------------------------------------------------------------
class TestNextChunkThreshold:
    def test_below_single_pass_returns_single_pass(self):
        result = cc._next_chunk_threshold_for_merge_bug(100)
        assert result == cc._CHUNK_TOKEN_THRESHOLD_SINGLE_PASS

    def test_at_last_resort_threshold(self):
        result = cc._next_chunk_threshold_for_merge_bug(cc._CHUNK_TOKEN_THRESHOLD_LAST_RESORT - 1)
        assert result == cc._CHUNK_TOKEN_THRESHOLD_LAST_RESORT

    def test_at_mega_threshold(self):
        result = cc._next_chunk_threshold_for_merge_bug(cc._CHUNK_TOKEN_THRESHOLD_MEGA - 1)
        assert result == cc._CHUNK_TOKEN_THRESHOLD_MEGA

    def test_beyond_mega_returns_none(self):
        result = cc._next_chunk_threshold_for_merge_bug(cc._CHUNK_TOKEN_THRESHOLD_MEGA + 1)
        assert result is None


# ---------------------------------------------------------------------------
# _truncate_page_text
# ---------------------------------------------------------------------------
class TestTruncatePageText:
    def test_short_text_returned_unchanged(self):
        text = "short text"
        assert cc._truncate_page_text(text, 1000) == "short text"

    def test_long_text_truncated(self):
        text = "a" * 10000
        result = cc._truncate_page_text(text, 100)
        assert len(result) <= 10000  # should be much shorter
        assert "truncated" in result or "omitted" in result

    def test_empty_text(self):
        assert cc._truncate_page_text("", 1000) == ""

    def test_none_text(self):
        assert cc._truncate_page_text(None, 1000) == ""


# ---------------------------------------------------------------------------
# _strip_llm_json_fences
# ---------------------------------------------------------------------------
class TestStripLlmJsonFences:
    def test_no_fence_unchanged(self):
        text = '{"key": "value"}'
        assert cc._strip_llm_json_fences(text) == text

    def test_json_fence_stripped(self):
        text = "```json\n{\"key\": \"value\"}\n```"
        result = cc._strip_llm_json_fences(text)
        assert result == '{"key": "value"}'

    def test_plain_fence_stripped(self):
        text = "```\n{\"key\": \"value\"}\n```"
        result = cc._strip_llm_json_fences(text)
        assert '{"key": "value"}' in result

    def test_empty_string(self):
        assert cc._strip_llm_json_fences("") == ""

    def test_none_returns_empty(self):
        assert cc._strip_llm_json_fences(None) == ""

    def test_fence_without_closing_handled(self):
        text = "```json\n{\"key\": \"value\"}"
        result = cc._strip_llm_json_fences(text)
        assert '{"key": "value"}' in result


# ---------------------------------------------------------------------------
# _looks_like_html
# ---------------------------------------------------------------------------
class TestLooksLikeHtml:
    def test_empty_returns_false(self):
        assert cc._looks_like_html("") is False

    def test_none_returns_false(self):
        assert cc._looks_like_html(None) is False

    def test_short_html_returns_false(self):
        assert cc._looks_like_html("<html>") is False  # < 80 chars

    def test_full_html_returns_true(self):
        html = "<html><body>" + "<div>Some content here</div>" * 5 + "</body></html>"
        assert cc._looks_like_html(html) is True

    def test_plain_text_returns_false(self):
        text = "This is plain text without any HTML tags at all. " * 3
        assert cc._looks_like_html(text) is False

    def test_article_html_returns_true(self):
        html = "<article>" + "Some article content." * 10 + "</article>"
        assert cc._looks_like_html(html) is True


# ---------------------------------------------------------------------------
# _two_step_extract_enabled
# ---------------------------------------------------------------------------
class TestTwoStepExtractEnabled:
    def test_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_TWO_STEP_EXTRACT", raising=False)
        assert cc._two_step_extract_enabled() is False

    def test_enabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_TWO_STEP_EXTRACT", "1")
        assert cc._two_step_extract_enabled() is True


# ---------------------------------------------------------------------------
# _pdf_max_pages
# ---------------------------------------------------------------------------
class TestPdfMaxPages:
    def test_default_is_40(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PDF_MAX_PAGES", raising=False)
        assert cc._pdf_max_pages() == 40

    def test_custom_value(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PDF_MAX_PAGES", "10")
        assert cc._pdf_max_pages() == 10

    def test_minimum_enforced(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PDF_MAX_PAGES", "0")
        assert cc._pdf_max_pages() == 1

    def test_invalid_value_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PDF_MAX_PAGES", "abc")
        assert cc._pdf_max_pages() == 40


# ---------------------------------------------------------------------------
# _direct_llm_extract_enabled
# ---------------------------------------------------------------------------
class TestDirectLlmExtractEnabled:
    def test_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DIRECT_LLM_EXTRACT", raising=False)
        assert cc._direct_llm_extract_enabled() is True

    def test_disabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DIRECT_LLM_EXTRACT", "0")
        assert cc._direct_llm_extract_enabled() is False


# ---------------------------------------------------------------------------
# _http_first_enabled
# ---------------------------------------------------------------------------
class TestHttpFirstEnabled:
    def test_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        assert cc._http_first_enabled() is True

    def test_disabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_HTTP_FIRST", "false")
        assert cc._http_first_enabled() is False


# ---------------------------------------------------------------------------
# _rate_limit_sleep_seconds_core
# ---------------------------------------------------------------------------
class TestRateLimitSleepSecondsCore:
    def test_returns_45_for_429_message(self):
        result = cc._rate_limit_sleep_seconds_core("Error 429: rate limit exceeded")
        assert result == 45.0

    def test_returns_10_for_generic_error(self):
        result = cc._rate_limit_sleep_seconds_core("some other error")
        assert result == 10.0

    def test_empty_message_returns_10(self):
        result = cc._rate_limit_sleep_seconds_core("")
        assert result == 10.0

    def test_rate_limit_string_returns_45(self):
        result = cc._rate_limit_sleep_seconds_core("rate limit hit")
        assert result == 45.0


# ---------------------------------------------------------------------------
# _is_chunk_merge_usage_bug
# ---------------------------------------------------------------------------
class TestIsChunkMergeUsageBug:
    def test_detects_usage_bug(self):
        assert cc._is_chunk_merge_usage_bug("'list' object has no attribute 'usage'") is True

    def test_empty_returns_false(self):
        assert cc._is_chunk_merge_usage_bug("") is False

    def test_none_returns_false(self):
        assert cc._is_chunk_merge_usage_bug(None) is False

    def test_other_error_returns_false(self):
        assert cc._is_chunk_merge_usage_bug("some other error message") is False


# ---------------------------------------------------------------------------
# _crawl_page_timeout_ms
# ---------------------------------------------------------------------------
class TestCrawlPageTimeoutMs:
    def test_default_is_75000(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PAGE_TIMEOUT_MS", raising=False)
        assert cc._crawl_page_timeout_ms() == 75000

    def test_custom_value(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PAGE_TIMEOUT_MS", "30000")
        assert cc._crawl_page_timeout_ms() == 30000

    def test_minimum_enforced(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PAGE_TIMEOUT_MS", "100")
        assert cc._crawl_page_timeout_ms() == 15000

    def test_invalid_falls_back(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PAGE_TIMEOUT_MS", "invalid")
        assert cc._crawl_page_timeout_ms() == 75000


# ---------------------------------------------------------------------------
# _crawl_wait_until
# ---------------------------------------------------------------------------
class TestCrawlWaitUntil:
    def test_default_is_load(self, monkeypatch):
        monkeypatch.delenv("CRAWL_WAIT_UNTIL", raising=False)
        assert cc._crawl_wait_until() == "load"

    def test_domcontentloaded(self, monkeypatch):
        monkeypatch.setenv("CRAWL_WAIT_UNTIL", "domcontentloaded")
        assert cc._crawl_wait_until() == "domcontentloaded"

    def test_invalid_falls_back_to_load(self, monkeypatch):
        monkeypatch.setenv("CRAWL_WAIT_UNTIL", "unknown")
        assert cc._crawl_wait_until() == "load"

    def test_networkidle_accepted(self, monkeypatch):
        monkeypatch.setenv("CRAWL_WAIT_UNTIL", "networkidle")
        assert cc._crawl_wait_until() == "networkidle"


# ---------------------------------------------------------------------------
# _direct_llm_max_chars
# ---------------------------------------------------------------------------
class TestDirectLlmMaxChars:
    def test_default_is_120000(self, monkeypatch):
        monkeypatch.delenv("CRAWL_DIRECT_LLM_MAX_CHARS", raising=False)
        assert cc._direct_llm_max_chars() == 120000

    def test_custom_value(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DIRECT_LLM_MAX_CHARS", "50000")
        assert cc._direct_llm_max_chars() == 50000

    def test_minimum_enforced(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DIRECT_LLM_MAX_CHARS", "100")
        assert cc._direct_llm_max_chars() == 8000

    def test_invalid_falls_back(self, monkeypatch):
        monkeypatch.setenv("CRAWL_DIRECT_LLM_MAX_CHARS", "not_a_number")
        assert cc._direct_llm_max_chars() == 120000


# ---------------------------------------------------------------------------
# RateLimiter
# ---------------------------------------------------------------------------
class TestRateLimiter:
    def test_acquire_within_limit(self):
        limiter = cc.RateLimiter(max_calls=10, period=60.0)

        async def _run():
            await limiter.acquire()

        asyncio.run(_run())
        assert len(limiter._timestamps) == 1

    def test_acquire_creates_lock_lazily(self):
        limiter = cc.RateLimiter(max_calls=5, period=60.0)
        assert limiter._lock is None

        async def _run():
            await limiter.acquire()

        asyncio.run(_run())
        assert limiter._lock is not None


# ---------------------------------------------------------------------------
# RateLimiter – window eviction and overflow branches
# ---------------------------------------------------------------------------
class TestRateLimiterEviction:
    def test_evicts_old_timestamps(self):
        """Old timestamps outside the window should be removed on acquire."""
        import time
        limiter = cc.RateLimiter(max_calls=5, period=0.05)

        async def _run():
            # Pre-seed with an old timestamp (1 hour ago)
            limiter._timestamps.append(time.monotonic() - 3600)
            await limiter.acquire()

        asyncio.run(_run())
        # The old timestamp should be evicted, only the new one remains
        assert len(limiter._timestamps) == 1

    def test_waits_when_window_full(self):
        """When window is full, should sleep until space opens up."""
        with patch("infrastructure.crawler_client.asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
            limiter = cc.RateLimiter(max_calls=1, period=60.0)

            async def _run():
                # Seed the limiter as if we already made 1 call
                import time
                limiter._timestamps.append(time.monotonic())
                # Now try to acquire again — window is full
                await limiter.acquire()

            asyncio.run(_run())
        # sleep should have been called to wait out the window
        mock_sleep.assert_called()


# ---------------------------------------------------------------------------
# _get_llm_concurrency_sem – ValueError branch
# ---------------------------------------------------------------------------
class TestGetLlmConcurrencySem:
    def test_invalid_env_defaults_to_1(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setenv("LLM_CONCURRENCY", "not_a_number")
        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        sem = cc._get_llm_concurrency_sem()
        assert sem is not None
        # Reset for other tests
        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)


# ---------------------------------------------------------------------------
# _llm_request_slot – spacing and jitter branches
# ---------------------------------------------------------------------------
class TestLlmRequestSlotBranches:
    def test_spacing_invalid_env_uses_default(self, monkeypatch):
        import infrastructure.crawler_client as cc
        from infrastructure.crawler_client import _llm_request_slot

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setattr(cc, "_llm_last_completed_at", 0.0)
        monkeypatch.setenv("LLM_CONCURRENCY", "1")
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "not_a_number")  # triggers ValueError branch
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "0")

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", new_callable=AsyncMock):
                async with _llm_request_slot():
                    pass

        asyncio.run(_run())

    def test_spacing_applied_when_last_completed_recent(self, monkeypatch):
        import time
        import infrastructure.crawler_client as cc
        from infrastructure.crawler_client import _llm_request_slot

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        # Set last_completed very recently to trigger the gap < spacing branch
        monkeypatch.setattr(cc, "_llm_last_completed_at", time.monotonic())
        monkeypatch.setenv("LLM_CONCURRENCY", "1")
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "100")  # very large spacing
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "0")

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
                async with _llm_request_slot():
                    pass
                return mock_sleep

        mock_sleep = asyncio.run(_run())
        mock_sleep.assert_called()  # sleep was called for spacing

    def test_jitter_invalid_env_uses_default(self, monkeypatch):
        import infrastructure.crawler_client as cc
        from infrastructure.crawler_client import _llm_request_slot

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setattr(cc, "_llm_last_completed_at", 0.0)
        monkeypatch.setenv("LLM_CONCURRENCY", "1")
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "not_a_number")  # triggers ValueError
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "not_a_number")  # triggers ValueError

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", new_callable=AsyncMock):
                async with _llm_request_slot():
                    pass

        asyncio.run(_run())

    def test_jitter_applied_when_jmax_positive(self, monkeypatch):
        import infrastructure.crawler_client as cc
        from infrastructure.crawler_client import _llm_request_slot

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setattr(cc, "_llm_last_completed_at", 0.0)
        monkeypatch.setenv("LLM_CONCURRENCY", "1")
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0.1")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "0.2")

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
                async with _llm_request_slot():
                    pass
                return mock_sleep

        mock_sleep = asyncio.run(_run())
        mock_sleep.assert_called()  # jitter sleep was called


# ---------------------------------------------------------------------------
# _require_llm_api_key – comma-separated empty first segment
# ---------------------------------------------------------------------------
class TestRequireLlmApiKeyEmpty:
    def test_comma_only_raises(self):
        from infrastructure.crawler_client import _require_llm_api_key
        import pytest
        with pytest.raises(ValueError):
            _require_llm_api_key(",")  # first segment is empty

    def test_valid_key_returned(self):
        from infrastructure.crawler_client import _require_llm_api_key
        assert _require_llm_api_key("sk-test") == "sk-test"

    def test_first_of_multiple_keys_returned(self):
        from infrastructure.crawler_client import _require_llm_api_key
        assert _require_llm_api_key("sk-first,sk-second") == "sk-first"
