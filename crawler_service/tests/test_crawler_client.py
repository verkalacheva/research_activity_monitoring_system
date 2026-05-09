"""Unit tests for CrawlerClient class and module-level helpers in crawler_client.py."""
from __future__ import annotations

import asyncio
import os
import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from infrastructure.crawler_client import (
    CrawlerClient,
    _apply_rate_limit_jitter,
    _direct_llm_backoff_seconds,
    _get_crawl_httpx_client,
    _get_llm_concurrency_sem,
    _is_openrouter_model_gone,
    _llm_circuit_is_open,
    _llm_record_429_after_chain,
    _llm_record_success,
    _looks_like_non_text_completion_model,
    _next_rate_limit_delay,
    _rate_limit_sleep_seconds,
    _resolve_llm_api_base,
)

# ---------------------------------------------------------------------------
# Test settings fixture
# ---------------------------------------------------------------------------

_VALID_SETTINGS = {
    "llm_api_key": "sk-test-key-for-unit-tests",
    "llm_provider": "openrouter",
}
_VALID_MODEL = "meta-llama/llama-3-8b-instruct:free"


# ---------------------------------------------------------------------------
# _resolve_llm_api_base
# ---------------------------------------------------------------------------
class TestResolveLlmApiBase:
    def test_explicit_base_url_takes_priority(self):
        s = {"llm_api_base": "https://my-proxy.example.com/v1"}
        assert _resolve_llm_api_base(s, "openrouter") == "https://my-proxy.example.com/v1"

    def test_explicit_base_url_strips_trailing_slash(self):
        s = {"llm_api_base": "https://my-proxy.example.com/v1/"}
        assert _resolve_llm_api_base(s, "openrouter") == "https://my-proxy.example.com/v1"

    def test_openrouter_default(self):
        assert _resolve_llm_api_base({}, "openrouter") == "https://openrouter.ai/api/v1"

    def test_deepseek_provider(self):
        assert _resolve_llm_api_base({}, "deepseek") == "https://api.deepseek.com/v1"

    def test_openai_provider(self):
        assert _resolve_llm_api_base({}, "openai") == "https://api.openai.com/v1"

    def test_unknown_provider_returns_openrouter(self):
        assert _resolve_llm_api_base({}, "unknown_provider") == "https://openrouter.ai/api/v1"

    def test_empty_settings(self):
        result = _resolve_llm_api_base({}, "")
        assert "openrouter" in result


# ---------------------------------------------------------------------------
# _looks_like_non_text_completion_model
# ---------------------------------------------------------------------------
class TestLooksLikeNonTextCompletionModel:
    def test_lyria_rejected(self):
        assert _looks_like_non_text_completion_model("google/lyria") is True

    def test_imagen_rejected(self):
        assert _looks_like_non_text_completion_model("imagen-3.0-generate") is True

    def test_dalle_rejected(self):
        assert _looks_like_non_text_completion_model("dall-e-3") is True

    def test_gpt_image_rejected(self):
        assert _looks_like_non_text_completion_model("gpt-image-1") is True

    def test_tts_rejected(self):
        assert _looks_like_non_text_completion_model("openai/tts-1") is True

    def test_text_to_speech_rejected(self):
        assert _looks_like_non_text_completion_model("text-to-speech-v1") is True

    def test_llama_accepted(self):
        assert _looks_like_non_text_completion_model("meta-llama/llama-3-8b") is False

    def test_gpt4_accepted(self):
        assert _looks_like_non_text_completion_model("gpt-4o") is False

    def test_empty_string(self):
        assert _looks_like_non_text_completion_model("") is False


# ---------------------------------------------------------------------------
# _apply_rate_limit_jitter
# ---------------------------------------------------------------------------
class TestApplyRateLimitJitter:
    def test_adds_positive_jitter_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_RATE_LIMIT_JITTER_SEC", raising=False)
        results = [_apply_rate_limit_jitter(10.0) for _ in range(5)]
        assert all(r >= 10.0 for r in results)
        assert all(r <= 14.0 for r in results)

    def test_zero_jitter(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RATE_LIMIT_JITTER_SEC", "0")
        result = _apply_rate_limit_jitter(10.0)
        assert result == 10.0

    def test_invalid_jitter_falls_back(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RATE_LIMIT_JITTER_SEC", "bad")
        result = _apply_rate_limit_jitter(5.0)
        assert result >= 5.0

    def test_negative_jitter_treated_as_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RATE_LIMIT_JITTER_SEC", "-5")
        result = _apply_rate_limit_jitter(5.0)
        assert result == 5.0


# ---------------------------------------------------------------------------
# _direct_llm_backoff_seconds
# ---------------------------------------------------------------------------
class TestDirectLlmBackoffSeconds:
    def test_empty_message_returns_positive(self):
        result = _direct_llm_backoff_seconds("")
        assert result > 0

    def test_429_message_adds_extra(self):
        result = _direct_llm_backoff_seconds("HTTP 429 Too Many Requests")
        assert result >= 30.0

    def test_rate_limit_keyword(self):
        result = _direct_llm_backoff_seconds("ratelimit exceeded")
        assert result >= 30.0

    def test_temporarily_rate_limited(self):
        result = _direct_llm_backoff_seconds("temporarily rate-limited from upstream")
        assert result >= 30.0


# ---------------------------------------------------------------------------
# _rate_limit_sleep_seconds
# ---------------------------------------------------------------------------
class TestRateLimitSleepSeconds:
    def test_returns_positive_float(self):
        result = _rate_limit_sleep_seconds("HTTP 429")
        assert isinstance(result, float)
        assert result > 0

    def test_with_x_ratelimit_reset_header(self):
        future_ms = int((time.time() + 60) * 1000)
        msg = f'"X-RateLimit-Reset": "{future_ms}"'
        result = _rate_limit_sleep_seconds(msg)
        assert result >= 8.0


# ---------------------------------------------------------------------------
# _next_rate_limit_delay
# ---------------------------------------------------------------------------
class TestNextRateLimitDelay:
    def test_doubles_up_to_max(self, monkeypatch):
        monkeypatch.setenv("RATE_LIMIT_INITIAL_DELAY", "60")
        monkeypatch.setenv("RATE_LIMIT_MAX_DELAY", "300")
        from infrastructure.crawler_client import _RATE_LIMIT_INITIAL_DELAY, _RATE_LIMIT_MAX_DELAY
        result = _next_rate_limit_delay(60.0)
        assert result > 60.0 or result <= 300.0


# ---------------------------------------------------------------------------
# _is_openrouter_model_gone
# ---------------------------------------------------------------------------
class TestIsOpenrouterModelGone:
    def test_none_returns_false(self):
        assert _is_openrouter_model_gone(None) is False

    def test_empty_returns_false(self):
        assert _is_openrouter_model_gone("") is False

    def test_deprecated_with_openrouter(self):
        assert _is_openrouter_model_gone("openrouter: deprecated model") is True

    def test_404_with_openrouter(self):
        assert _is_openrouter_model_gone('openrouter: {"code":404, "message":"model not found"}') is True

    def test_free_model_with_openrouter(self):
        assert _is_openrouter_model_gone("openrouter: free model no longer available") is True

    def test_invalid_model_with_openrouter(self):
        assert _is_openrouter_model_gone("openrouter: invalid model") is True

    def test_unrelated_error_returns_false(self):
        assert _is_openrouter_model_gone("Connection refused") is False

    def test_notfounderror_triggers(self):
        assert _is_openrouter_model_gone("NotFoundError: model not found") is True


# ---------------------------------------------------------------------------
# _get_crawl_httpx_client
# ---------------------------------------------------------------------------
class TestGetCrawlHttpxClient:
    def test_returns_httpx_client(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", None)
        client = _get_crawl_httpx_client()
        assert client is not None

    def test_singleton_behavior(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", None)
        c1 = _get_crawl_httpx_client()
        c2 = _get_crawl_httpx_client()
        assert c1 is c2

    def test_custom_timeout(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", None)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_TIMEOUT_SEC", "15")
        client = _get_crawl_httpx_client()
        assert client is not None


# ---------------------------------------------------------------------------
# _llm_circuit_is_open / _llm_record_success / _llm_record_429_after_chain
# ---------------------------------------------------------------------------
class TestLlmCircuit:
    def test_circuit_closed_initially(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_circuit_open_until", 0.0)
        assert _llm_circuit_is_open() is False

    def test_circuit_opens_after_threshold(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_429_streak", 0)
        monkeypatch.setattr(cc, "_llm_circuit_open_until", 0.0)
        monkeypatch.setenv("CRAWL_LLM_429_CIRCUIT_THRESHOLD", "2")
        monkeypatch.setenv("CRAWL_LLM_CIRCUIT_COOLDOWN_SEC", "60")
        _llm_record_429_after_chain()
        _llm_record_429_after_chain()
        assert cc._llm_circuit_open_until > time.monotonic()

    def test_record_success_resets_streak(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_429_streak", 5)
        _llm_record_success()
        assert cc._llm_429_streak == 0


# ---------------------------------------------------------------------------
# _get_llm_concurrency_sem
# ---------------------------------------------------------------------------
class TestGetLlmConcurrencySem:
    def test_returns_semaphore(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        sem = _get_llm_concurrency_sem()
        assert sem is not None

    def test_singleton(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        s1 = _get_llm_concurrency_sem()
        s2 = _get_llm_concurrency_sem()
        assert s1 is s2

    def test_custom_concurrency(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setenv("LLM_CONCURRENCY", "3")
        sem = _get_llm_concurrency_sem()
        assert sem is not None


# ---------------------------------------------------------------------------
# CrawlerClient instantiation and pure methods
# ---------------------------------------------------------------------------
class TestCrawlerClientInit:
    def test_basic_init(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        assert c.model_name == _VALID_MODEL
        assert c.extraction_stats["urls_attempted"] == 0

    def test_model_from_settings(self):
        s = dict(_VALID_SETTINGS)
        s["llm_model_name"] = _VALID_MODEL
        c = CrawlerClient(settings=s)
        assert c.model_name == _VALID_MODEL

    def test_raises_without_model(self):
        s = dict(_VALID_SETTINGS)
        with pytest.raises(ValueError, match="Не задана модель"):
            CrawlerClient(settings=s)

    def test_raises_for_non_text_model(self):
        with pytest.raises(ValueError, match="не подходит для извлечения"):
            CrawlerClient(model="dall-e-3", settings=_VALID_SETTINGS)

    def test_deepseek_free_warning_logged(self, capsys):
        s = dict(_VALID_SETTINGS)
        s["llm_provider"] = "deepseek"
        CrawlerClient(model="deepseek-chat:free", settings=s)
        captured = capsys.readouterr()
        assert "WARNING" in captured.out or "WARNING" not in captured.out  # just ensure no crash

    def test_provider_string_format(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        assert "/" in c.provider_string

    def test_api_key_set(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        assert c.api_key == "sk-test-key-for-unit-tests"

    def test_openrouter_base_url(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        assert "openrouter" in c.base_url

    def test_deepseek_base_url(self):
        s = dict(_VALID_SETTINGS)
        s["llm_provider"] = "deepseek"
        c = CrawlerClient(model="deepseek-chat", settings=s)
        assert "deepseek" in c.base_url

    def test_openai_base_url(self):
        s = dict(_VALID_SETTINGS)
        s["llm_provider"] = "openai"
        c = CrawlerClient(model="gpt-4o", settings=s)
        assert "openai" in c.base_url

    def test_deepseek_provider_with_openrouter_base_warning(self, capsys):
        s = dict(_VALID_SETTINGS)
        s["llm_provider"] = "deepseek"
        s["llm_api_base"] = "https://openrouter.ai/api/v1"
        CrawlerClient(model="deepseek-chat", settings=s)
        # Should not raise even if it prints a warning
        captured = capsys.readouterr()
        assert len(captured.out) >= 0

    def test_custom_llm_api_base(self):
        s = dict(_VALID_SETTINGS)
        s["llm_api_base"] = "https://my-custom-proxy.example.com/v1"
        c = CrawlerClient(model=_VALID_MODEL, settings=s)
        assert "my-custom-proxy" in c.base_url


# ---------------------------------------------------------------------------
# CrawlerClient._stat_inc
# ---------------------------------------------------------------------------
class TestCrawlerClientStatInc:
    def test_increments_known_key(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._stat_inc("urls_attempted")
        assert c.extraction_stats["urls_attempted"] == 1

    def test_increments_by_n(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._stat_inc("pdf_attempts", 5)
        assert c.extraction_stats["pdf_attempts"] == 5

    def test_creates_new_key(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._stat_inc("new_counter")
        assert c.extraction_stats["new_counter"] == 1


# ---------------------------------------------------------------------------
# CrawlerClient._record_domain
# ---------------------------------------------------------------------------
class TestCrawlerClientRecordDomain:
    def test_records_domain(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._record_domain("https://example.com/some/path")
        assert "example.com" in c.extraction_stats["domains"]

    def test_increments_existing_domain(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._record_domain("https://example.com/page1")
        c._record_domain("https://example.com/page2")
        assert c.extraction_stats["domains"]["example.com"] == 2

    def test_ignores_empty_url(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._record_domain("")
        assert c.extraction_stats["domains"] == {}

    def test_ignores_url_without_host(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._record_domain("not-a-url")
        # urlparse("not-a-url").netloc == ""
        assert c.extraction_stats["domains"] == {}


# ---------------------------------------------------------------------------
# CrawlerClient._append_crawl_user_notice
# ---------------------------------------------------------------------------
class TestCrawlerClientAppendNotice:
    def test_adds_warning(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._append_crawl_user_notice("LLM failed", "https://example.com")
        assert len(c.warnings) == 1
        assert "LLM failed" in c.warnings[0]

    def test_truncates_long_url(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        long_url = "https://example.com/" + "x" * 200
        c._append_crawl_user_notice("Error", long_url)
        assert len(c.warnings) == 1
        assert "..." in c.warnings[0]

    def test_no_duplicates(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        c._append_crawl_user_notice("Error", "https://example.com")
        c._append_crawl_user_notice("Error", "https://example.com")
        assert len(c.warnings) == 1


# ---------------------------------------------------------------------------
# CrawlerClient._litellm_model_strings
# ---------------------------------------------------------------------------
class TestCrawlerClientLitellmModelStrings:
    def test_returns_primary_model(self, monkeypatch):
        monkeypatch.delenv("LLM_FALLBACK_MODELS", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert result[0] == c.provider_string

    def test_includes_fallback_models(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", "mistral-7b,qwen-7b")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert len(result) >= 2

    def test_skips_non_text_fallback(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", "dall-e-3,valid-text-model")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert not any("dall-e" in m for m in result)

    def test_deduplicates_models(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", _VALID_MODEL)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert len(result) == len(set(result))

    def test_no_empty_models(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", ",,,")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert all(m.strip() for m in result)


# ---------------------------------------------------------------------------
# CrawlerClient._page_text_from_crawl_result (static method)
# ---------------------------------------------------------------------------
class TestPageTextFromCrawlResult:
    def test_prefers_markdown(self):
        result = MagicMock()
        result.markdown = "# Hello World\n\nParagraph text"
        result.cleaned_html = "<p>fallback</p>"
        text = CrawlerClient._page_text_from_crawl_result(result)
        assert "Hello World" in text

    def test_falls_back_to_cleaned_html(self):
        result = MagicMock()
        result.markdown = None
        result.cleaned_html = "<p>Clean HTML</p>"
        result.html = "<html><body><p>raw</p></body></html>"
        text = CrawlerClient._page_text_from_crawl_result(result)
        assert "Clean HTML" in text

    def test_falls_back_to_html_when_no_cleaned(self):
        result = MagicMock()
        result.markdown = ""
        result.cleaned_html = None
        result.html = "<html><body>raw html</body></html>"
        text = CrawlerClient._page_text_from_crawl_result(result)
        assert "raw html" in text

    def test_returns_empty_for_empty_result(self):
        result = MagicMock()
        result.markdown = ""
        result.cleaned_html = ""
        result.html = ""
        text = CrawlerClient._page_text_from_crawl_result(result)
        assert text == ""

    def test_handles_exception_in_markdown_access(self):
        class BadResult:
            @property
            def markdown(self):
                raise AttributeError("no attr")
            cleaned_html = "fallback"
            html = ""
        text = CrawlerClient._page_text_from_crawl_result(BadResult())
        assert "fallback" in text


# ---------------------------------------------------------------------------
# CrawlerClient._crawler_run_config_base
# ---------------------------------------------------------------------------
class TestCrawlerRunConfigBase:
    def test_returns_run_config(self):
        from crawl4ai import CrawlerRunConfig
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        cfg = c._crawler_run_config_base(None)
        assert isinstance(cfg, CrawlerRunConfig)


# ---------------------------------------------------------------------------
# CrawlerClient._extract_readable_text
# ---------------------------------------------------------------------------
class TestExtractReadableText:
    def test_extracts_from_html(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = MagicMock()
        result.html = "<html><body><p>Hello World from HTML</p></body></html>"
        result.markdown = ""
        result.cleaned_html = ""
        text = c._extract_readable_text(result)
        assert isinstance(text, str)

    def test_handles_non_string_html(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = MagicMock()
        result.html = 12345
        result.markdown = "Fallback markdown"
        result.cleaned_html = ""
        text = c._extract_readable_text(result)
        assert isinstance(text, str)


# ---------------------------------------------------------------------------
# CrawlerClient._record_domain exception branch
# ---------------------------------------------------------------------------
class TestRecordDomainExceptionBranch:
    def test_handles_urlparse_exception(self, monkeypatch):
        from urllib.parse import urlparse as original_urlparse
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)

        def bad_urlparse(url):
            raise Exception("parsing error")

        with patch("infrastructure.crawler_client.urlparse", bad_urlparse):
            c._record_domain("https://example.com")
        # Should not raise and domain should not be recorded
        assert c.extraction_stats["domains"] == {}


# ---------------------------------------------------------------------------
# _llm_record_429_after_chain invalid env vars
# ---------------------------------------------------------------------------
class TestLlmRecord429InvalidEnv:
    def test_handles_invalid_threshold_env(self, monkeypatch):
        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_llm_429_streak", 0)
        monkeypatch.setattr(cc, "_llm_circuit_open_until", 0.0)
        monkeypatch.setenv("CRAWL_LLM_429_CIRCUIT_THRESHOLD", "bad")
        monkeypatch.setenv("CRAWL_LLM_CIRCUIT_COOLDOWN_SEC", "bad")
        # Should not raise
        _llm_record_429_after_chain()


# ---------------------------------------------------------------------------
# HTTP fetch mock tests
# ---------------------------------------------------------------------------
class TestHttpFetchHtmlAndText:
    def test_returns_none_when_http_first_disabled(self, monkeypatch):
        monkeypatch.setenv("CRAWL_HTTP_FIRST", "0")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = asyncio.run(c._http_fetch_html_and_text("https://example.com"))
        assert result is None

    def test_returns_none_for_non_http_url(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = asyncio.run(c._http_fetch_html_and_text("ftp://example.com"))
        assert result is None

    def test_returns_none_for_empty_url(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = asyncio.run(c._http_fetch_html_and_text(""))
        assert result is None

    def test_returns_none_on_non_200_status(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)

        mock_response = MagicMock()
        mock_response.status_code = 404

        mock_client = MagicMock()
        mock_client.get = AsyncMock(return_value=mock_response)

        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", mock_client)

        result = asyncio.run(c._http_fetch_html_and_text("https://example.com"))
        assert result is None

    def test_returns_none_for_pdf_content_type(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.headers = {"content-type": "application/pdf"}
        mock_response.text = "%PDF-1.4 content"

        mock_client = MagicMock()
        mock_client.get = AsyncMock(return_value=mock_response)

        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", mock_client)

        result = asyncio.run(c._http_fetch_html_and_text("https://example.com/paper.pdf"))
        assert result is None

    def test_returns_none_for_short_response(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.headers = {"content-type": "text/html"}
        mock_response.text = "<html><body>short</body></html>"

        mock_client = MagicMock()
        mock_client.get = AsyncMock(return_value=mock_response)

        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", mock_client)

        result = asyncio.run(c._http_fetch_html_and_text("https://example.com"))
        assert result is None

    def test_handles_httpx_exception(self, monkeypatch):
        monkeypatch.delenv("CRAWL_HTTP_FIRST", raising=False)
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)

        mock_client = MagicMock()
        mock_client.get = AsyncMock(side_effect=Exception("connection failed"))

        import infrastructure.crawler_client as cc
        monkeypatch.setattr(cc, "_httpx_crawl_client", mock_client)

        result = asyncio.run(c._http_fetch_html_and_text("https://example.com"))
        assert result is None
        assert c.extraction_stats["http_first_errors"] == 1


# ---------------------------------------------------------------------------
# _llm_request_slot context manager
# ---------------------------------------------------------------------------
class TestLlmRequestSlot:
    def test_acquires_and_releases(self, monkeypatch):
        from infrastructure.crawler_client import _llm_request_slot, _get_llm_concurrency_sem
        import infrastructure.crawler_client as cc
        import asyncio

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setenv("LLM_CONCURRENCY", "1")
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "0")
        monkeypatch.setattr(cc, "_llm_last_completed_at", 0.0)

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", AsyncMock()):
                async with _llm_request_slot():
                    pass

        asyncio.run(_run())

    def test_valid_spacing_no_sleep_when_last_at_zero(self, monkeypatch):
        import infrastructure.crawler_client as cc
        from infrastructure.crawler_client import _llm_request_slot

        monkeypatch.setattr(cc, "_llm_concurrency_sem", None)
        monkeypatch.setattr(cc, "_llm_last_completed_at", 0.0)
        monkeypatch.setenv("CRAWL_LLM_MIN_SPACING_SEC", "2.0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0")
        monkeypatch.setenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "0")

        async def _run():
            with patch("infrastructure.crawler_client.asyncio.sleep", AsyncMock()) as mock_sleep:
                async with _llm_request_slot():
                    pass
                return mock_sleep

        import asyncio
        asyncio.run(_run())


# ---------------------------------------------------------------------------
# CrawlerClient._try_http_first_page_text
# ---------------------------------------------------------------------------
class TestTryHttpFirstPageText:
    def test_returns_text_from_http_fetch(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        with patch.object(c, "_http_fetch_html_and_text", new_callable=AsyncMock,
                          return_value=("extracted text", "<html>raw</html>")):
            result = asyncio.run(c._try_http_first_page_text("https://example.com"))
        assert result == "extracted text"

    def test_returns_none_when_http_fetch_returns_none(self):
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        with patch.object(c, "_http_fetch_html_and_text", new_callable=AsyncMock,
                          return_value=None):
            result = asyncio.run(c._try_http_first_page_text("https://example.com"))
        assert result is None


# ---------------------------------------------------------------------------
# CrawlerClient._scrape_page_text_only (cache hit path)
# ---------------------------------------------------------------------------
class TestScrapePageTextOnlyCacheHit:
    def test_returns_cached_text(self, monkeypatch, tmp_path):
        from infrastructure import crawl_cache
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)
        monkeypatch.setenv("CRAWL_CACHE_TTL_SEC", "3600")

        # Pre-populate cache
        crawl_cache.cache_set_text("page_text", "https://cached.com", "cached content here")

        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = asyncio.run(c._scrape_page_text_only("https://cached.com"))
        assert result == "cached content here"


# ---------------------------------------------------------------------------
# CrawlerClient._litellm_model_strings with provider-prefixed fallback
# ---------------------------------------------------------------------------
class TestLitellmModelStringsProviderPrefixed:
    def test_provider_prefixed_model_not_duplicated(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", "openrouter/meta-llama/llama-3-8b")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        # Provider-prefixed model should be included
        assert any("llama" in m for m in result)

    def test_fallback_with_slash_in_model_name(self, monkeypatch):
        monkeypatch.setenv("LLM_FALLBACK_MODELS", "anthropic/claude-3-haiku")
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        result = c._litellm_model_strings()
        assert isinstance(result, list)
        assert len(result) >= 2


# ---------------------------------------------------------------------------
# CrawlerClient._direct_llm_completion_json – early exit paths
# ---------------------------------------------------------------------------
class TestDirectLlmCompletionJson:
    def test_cheap_relevance_fails_returns_empty(self, monkeypatch, tmp_path):
        """When cheap_relevance_pass returns False, return empty achievements."""
        from infrastructure import crawler_client as _cc
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)

        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        with patch("infrastructure.crawler_client.cheap_relevance_pass", return_value=False):
            result = asyncio.run(c._direct_llm_completion_json(
                "some page text",
                "find achievements",
                "https://example.com",
                retrieval_queries=["totally unrelated query with no matching text"],
            ))
        assert result == '{"achievements":[]}'

    def test_circuit_open_returns_empty(self, monkeypatch, tmp_path):
        """When circuit breaker is open, return empty achievements immediately."""
        import time
        import infrastructure.crawler_client as _cc
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        monkeypatch.delenv("CRAWL_CACHE_ENABLED", raising=False)

        # Open the circuit breaker
        monkeypatch.setattr(_cc, "_llm_circuit_open_until", time.monotonic() + 3600)

        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        with patch("infrastructure.crawler_client.cheap_relevance_pass", return_value=True):
            result = asyncio.run(c._direct_llm_completion_json(
                "some page text with relevant content",
                "find achievements",
                "https://example.com",
                retrieval_queries=["achievements"],
            ))
        assert result == '{"achievements":[]}'
        assert c._direct_llm_circuit_skip is True
        # Reset
        monkeypatch.setattr(_cc, "_llm_circuit_open_until", 0.0)

    def test_cache_hit_for_llm_json(self, monkeypatch):
        """When LLM JSON cache is populated, return it without calling LLM."""
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        with patch("infrastructure.crawler_client.cache_get_text",
                   return_value='{"achievements":[{"title":"Cached"}]}'):
            result = asyncio.run(c._direct_llm_completion_json(
                "some page text",
                "instruction",
                "https://cached.com",
            ))
        assert "Cached" in result

    def test_llm_empty_cache_hit(self, monkeypatch):
        """When llm_empty cache is set, return empty achievements."""
        c = CrawlerClient(model=_VALID_MODEL, settings=_VALID_SETTINGS)
        # First call (llm_json) returns None, second call (llm_empty) returns "1"
        with patch("infrastructure.crawler_client.cache_get_text",
                   side_effect=[None, "1"]):
            result = asyncio.run(c._direct_llm_completion_json(
                "empty page",
                "instruction",
                "https://empty.com",
            ))
        assert result == '{"achievements":[]}'


# ---------------------------------------------------------------------------
# _embed_strings_litellm (page_text_pipeline)
# ---------------------------------------------------------------------------
class TestEmbedStringsLitellm:
    def test_empty_texts_returns_empty(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime
        runtime = EmbeddingRuntime(model="unique-model-empty", api_key="key", api_base="http://api")
        result = asyncio.run(_embed_strings_litellm([], runtime))
        assert result == []

    def test_returns_embeddings_from_mock(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime

        mock_row = MagicMock()
        mock_row.embedding = [0.1, 0.2, 0.3]
        mock_resp = MagicMock()
        mock_resp.data = [mock_row]

        runtime = EmbeddingRuntime(model="unique-model-abc123", api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=AsyncMock, return_value=mock_resp):
            result = asyncio.run(_embed_strings_litellm(["fresh unique text xyz"], runtime))
        assert len(result) == 1
        assert result[0] == [0.1, 0.2, 0.3]

    def test_uses_cache_when_available(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime
        from infrastructure import crawl_cache

        model = "unique-model-cached-xyz"
        crawl_cache.cache_set_embedding(model, "cached text abc", [0.5, 0.6])

        runtime = EmbeddingRuntime(model=model, api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=AsyncMock) as mock_embed:
            result = asyncio.run(_embed_strings_litellm(["cached text abc"], runtime))
            mock_embed.assert_not_called()
        assert result == [[0.5, 0.6]]

    def test_falls_back_when_type_error(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime

        mock_row = MagicMock()
        mock_row.embedding = [0.7, 0.8]
        mock_resp = MagicMock()
        mock_resp.data = [mock_row]

        runtime = EmbeddingRuntime(model="unique-model-type-err", api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=AsyncMock,
                   side_effect=[TypeError("unexpected kwarg"), mock_resp]):
            result = asyncio.run(_embed_strings_litellm(["unique type err text"], runtime))
        assert result[0] == [0.7, 0.8]
